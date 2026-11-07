"""Start or stop EC2 instances and RDS databases that carry the schedule tag.

Invoked by EventBridge with a payload such as ``{"action": "stop"}``.
Optional ``"dry_run": true`` lists what would change without changing it.

Behaviour:
* Only resources tagged ``TAG_KEY=TAG_VALUE`` are touched (default ``Schedule=true``).
* Only resources in the opposite state are acted on (stop -> running, start -> stopped),
  so a repeated run is a no-op (idempotent).
* EC2 instances owned by an Auto Scaling group are skipped: stopping them would make
  the ASG replace them.
* DB clusters (Aurora, Multi-AZ DB clusters; the same API also lists Neptune and DocumentDB)
  are started and stopped at cluster level; their member instances are skipped.
* RDS read replicas, and sources that have replicas, are skipped: AWS cannot stop them.
* Every resource is attempted. If any call fails, the function raises at the end so the
  invocation is recorded as an error (CloudWatch ``Errors`` metric -> alarm).
"""

from __future__ import annotations

import json
import logging
import os
from itertools import batched
from typing import Any

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

VALID_ACTIONS = ("start", "stop")
EC2_BATCH_SIZE = 50
ASG_TAG = "aws:autoscaling:groupName"


class SchedulerError(Exception):
    """Raised when one or more start/stop calls failed."""


def _config() -> dict[str, Any]:
    return {
        "tag_key": os.environ.get("TAG_KEY", "Schedule"),
        "tag_value": os.environ.get("TAG_VALUE", "true"),
        "resource_types": [
            t.strip() for t in os.environ.get("RESOURCE_TYPES", "ec2,rds").split(",") if t.strip()
        ],
    }


def _log(message: str, **fields: Any) -> None:
    logger.info(json.dumps({"message": message, **fields}, default=str))


def _has_tag(tags: list[dict[str, str]], key: str, value: str) -> bool:
    return any(t.get("Key") == key and t.get("Value") == value for t in tags or [])


# --------------------------------------------------------------------------- EC2


def ec2_targets(ec2, action: str, tag_key: str, tag_value: str) -> list[str]:
    """Return IDs of tagged instances that are in the state the action applies to."""
    from_state = "running" if action == "stop" else "stopped"
    ids: list[str] = []
    paginator = ec2.get_paginator("describe_instances")
    filters = [
        {"Name": f"tag:{tag_key}", "Values": [tag_value]},
        {"Name": "instance-state-name", "Values": [from_state]},
    ]
    for page in paginator.paginate(Filters=filters):
        for reservation in page["Reservations"]:
            for instance in reservation["Instances"]:
                asg = instance_asg(instance)
                if asg:
                    _log(
                        "skip: managed by an Auto Scaling group",
                        instance_id=instance["InstanceId"],
                        asg=asg,
                    )
                    continue
                ids.append(instance["InstanceId"])
    return ids


def instance_asg(instance: dict[str, Any]) -> str:
    """Name of the ASG that owns the instance, or '' if none."""
    for tag in instance.get("Tags", []):
        if tag.get("Key") == ASG_TAG:
            return tag.get("Value", "")
    return ""


def apply_ec2(ec2, action: str, ids: list[str]) -> list[str]:
    """Start/stop instances in batches. Returns a list of error messages."""
    call = ec2.stop_instances if action == "stop" else ec2.start_instances
    errors: list[str] = []
    for batch in batched(ids, EC2_BATCH_SIZE):
        try:
            call(InstanceIds=list(batch))
            _log(f"ec2 {action} requested", instance_ids=list(batch))
        except Exception:  # noqa: BLE001
            # The API is all-or-nothing per call: one bad instance fails the whole batch.
            # Retry one by one so only the instance that really cannot change is reported.
            for instance_id in batch:
                try:
                    call(InstanceIds=[instance_id])
                    _log(f"ec2 {action} requested", instance_ids=[instance_id])
                except Exception as exc:  # noqa: BLE001 - collected, re-raised as SchedulerError
                    errors.append(f"ec2 {action} {instance_id}: {exc}")
    return errors


# --------------------------------------------------------------------------- RDS


def rds_targets(rds, action: str, tag_key: str, tag_value: str) -> dict[str, list[str]]:
    """Return tagged standalone DB instances and DB clusters in the right state."""
    from_status = "available" if action == "stop" else "stopped"
    instances: list[str] = []
    clusters: list[str] = []

    for page in rds.get_paginator("describe_db_instances").paginate():
        for db in page["DBInstances"]:
            if db.get("DBClusterIdentifier"):
                continue  # cluster member: handled at cluster level
            if db.get("ReadReplicaSourceDBInstanceIdentifier") or db.get(
                "ReadReplicaDBInstanceIdentifiers"
            ):
                # AWS cannot stop a read replica or a source that has replicas.
                _log(
                    "skip: read replica setup cannot be stopped",
                    db_instance=db["DBInstanceIdentifier"],
                )
                continue
            if db["DBInstanceStatus"] == from_status and _has_tag(
                db.get("TagList", []), tag_key, tag_value
            ):
                instances.append(db["DBInstanceIdentifier"])

    for page in rds.get_paginator("describe_db_clusters").paginate():
        for cluster in page["DBClusters"]:
            if cluster["Status"] == from_status and _has_tag(
                cluster.get("TagList", []), tag_key, tag_value
            ):
                clusters.append(cluster["DBClusterIdentifier"])

    return {"instances": instances, "clusters": clusters}


def apply_rds(rds, action: str, targets: dict[str, list[str]]) -> list[str]:
    """Start/stop each DB instance and cluster. Returns a list of error messages."""
    errors: list[str] = []
    for db_id in targets["instances"]:
        try:
            if action == "stop":
                rds.stop_db_instance(DBInstanceIdentifier=db_id)
            else:
                rds.start_db_instance(DBInstanceIdentifier=db_id)
            _log(f"rds instance {action} requested", db_instance=db_id)
        except Exception as exc:  # noqa: BLE001
            errors.append(f"rds instance {action} {db_id}: {exc}")
    for cluster_id in targets["clusters"]:
        try:
            if action == "stop":
                rds.stop_db_cluster(DBClusterIdentifier=cluster_id)
            else:
                rds.start_db_cluster(DBClusterIdentifier=cluster_id)
            _log(f"rds cluster {action} requested", db_cluster=cluster_id)
        except Exception as exc:  # noqa: BLE001
            errors.append(f"rds cluster {action} {cluster_id}: {exc}")
    return errors


# ----------------------------------------------------------------------- handler


def lambda_handler(event: dict[str, Any], context: Any = None) -> dict[str, Any]:
    action = (event or {}).get("action")
    if action not in VALID_ACTIONS:
        raise ValueError(f"event.action must be one of {VALID_ACTIONS}, got {action!r}")
    dry_run = event.get("dry_run", False)
    if not isinstance(dry_run, bool):
        raise ValueError(f"event.dry_run must be true or false, got {dry_run!r}")
    cfg = _config()
    summary: dict[str, Any] = {"action": action, "dry_run": dry_run}
    errors: list[str] = []

    if "ec2" in cfg["resource_types"]:
        ec2 = boto3.client("ec2")
        ids = ec2_targets(ec2, action, cfg["tag_key"], cfg["tag_value"])
        summary["ec2"] = ids
        if not dry_run:
            errors += apply_ec2(ec2, action, ids)

    if "rds" in cfg["resource_types"]:
        rds = boto3.client("rds")
        targets = rds_targets(rds, action, cfg["tag_key"], cfg["tag_value"])
        summary["rds"] = targets
        if not dry_run:
            errors += apply_rds(rds, action, targets)

    _log("run complete", **summary, error_count=len(errors))
    if errors:
        for err in errors:
            logger.error(err)
        raise SchedulerError(f"{len(errors)} call(s) failed: {errors}")
    return summary
