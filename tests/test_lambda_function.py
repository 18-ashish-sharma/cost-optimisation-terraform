"""Tests for the start/stop selection and failure logic, against moto's in-memory AWS."""

import boto3
import pytest
from moto import mock_aws

import lambda_function as lf

REGION = "ap-south-1"
SCHEDULED = [{"Key": "Schedule", "Value": "true"}]


@pytest.fixture(autouse=True)
def aws(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", REGION)
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("RESOURCE_TYPES", "ec2,rds")
    with mock_aws():
        yield


def _instance(ec2, tags):
    spec = [{"ResourceType": "instance", "Tags": tags}] if tags else []
    resp = ec2.run_instances(ImageId="ami-12c6146b", MinCount=1, MaxCount=1, TagSpecifications=spec)
    return resp["Instances"][0]["InstanceId"]


def _state(ec2, instance_id):
    r = ec2.describe_instances(InstanceIds=[instance_id])
    return r["Reservations"][0]["Instances"][0]["State"]["Name"]


def _db(rds, name, tags):
    rds.create_db_instance(
        DBInstanceIdentifier=name,
        DBInstanceClass="db.t3.micro",
        Engine="postgres",
        MasterUsername="admin_user",
        MasterUserPassword="not-a-real-password",
        AllocatedStorage=20,
        Tags=tags,
    )


def _db_status(rds, name):
    return rds.describe_db_instances(DBInstanceIdentifier=name)["DBInstances"][0][
        "DBInstanceStatus"
    ]


# ------------------------------------------------------------------ EC2


def test_stop_only_touches_tagged_instances():
    ec2 = boto3.client("ec2", region_name=REGION)
    tagged = _instance(ec2, SCHEDULED)
    untagged = _instance(ec2, [{"Key": "Name", "Value": "prod-api"}])
    wrong_value = _instance(ec2, [{"Key": "Schedule", "Value": "false"}])

    result = lf.lambda_handler({"action": "stop"})

    assert result["ec2"] == [tagged]
    assert _state(ec2, tagged) == "stopped"
    assert _state(ec2, untagged) == "running"
    assert _state(ec2, wrong_value) == "running"


def test_start_only_selects_stopped_instances_and_is_idempotent():
    ec2 = boto3.client("ec2", region_name=REGION)
    tagged = _instance(ec2, SCHEDULED)
    ec2.stop_instances(InstanceIds=[tagged])

    assert lf.lambda_handler({"action": "start"})["ec2"] == [tagged]
    assert _state(ec2, tagged) == "running"
    # Second run: nothing left in the "stopped" state, so nothing is selected.
    assert lf.lambda_handler({"action": "start"})["ec2"] == []


def test_instances_in_an_auto_scaling_group_are_skipped():
    ec2 = boto3.client("ec2", region_name=REGION)
    asg_member = _instance(ec2, SCHEDULED + [{"Key": lf.ASG_TAG, "Value": "web-asg"}])

    result = lf.lambda_handler({"action": "stop"})

    assert result["ec2"] == []
    assert _state(ec2, asg_member) == "running"


def test_dry_run_changes_nothing():
    ec2 = boto3.client("ec2", region_name=REGION)
    tagged = _instance(ec2, SCHEDULED)

    result = lf.lambda_handler({"action": "stop", "dry_run": True})

    assert result["ec2"] == [tagged]
    assert _state(ec2, tagged) == "running"


def test_no_tagged_resources_is_a_clean_no_op():
    result = lf.lambda_handler({"action": "stop"})
    assert result["ec2"] == []
    assert result["rds"] == {"instances": [], "clusters": []}


def test_custom_tag_key_and_value(monkeypatch):
    monkeypatch.setenv("TAG_KEY", "Environment")
    monkeypatch.setenv("TAG_VALUE", "dev")
    ec2 = boto3.client("ec2", region_name=REGION)
    dev = _instance(ec2, [{"Key": "Environment", "Value": "dev"}])
    _instance(ec2, SCHEDULED)

    assert lf.lambda_handler({"action": "stop"})["ec2"] == [dev]


# ------------------------------------------------------------------ RDS


def test_rds_stop_and_start_only_tagged_instances():
    rds = boto3.client("rds", region_name=REGION)
    _db(rds, "dev-db", SCHEDULED)
    _db(rds, "prod-db", [])

    assert lf.lambda_handler({"action": "stop"})["rds"]["instances"] == ["dev-db"]
    assert _db_status(rds, "dev-db") == "stopped"
    assert _db_status(rds, "prod-db") == "available"

    assert lf.lambda_handler({"action": "start"})["rds"]["instances"] == ["dev-db"]
    assert _db_status(rds, "dev-db") == "available"


def test_rds_cluster_is_handled_at_cluster_level():
    rds = boto3.client("rds", region_name=REGION)
    rds.create_db_cluster(
        DBClusterIdentifier="dev-aurora",
        Engine="aurora-postgresql",
        MasterUsername="admin_user",
        MasterUserPassword="not-a-real-password",
        Tags=SCHEDULED,
    )
    rds.create_db_instance(
        DBInstanceIdentifier="dev-aurora-1",
        DBInstanceClass="db.t3.medium",
        Engine="aurora-postgresql",
        DBClusterIdentifier="dev-aurora",
        Tags=SCHEDULED,
    )

    targets = lf.lambda_handler({"action": "stop"})["rds"]

    assert targets == {"instances": [], "clusters": ["dev-aurora"]}
    cluster = rds.describe_db_clusters(DBClusterIdentifier="dev-aurora")["DBClusters"][0]
    assert cluster["Status"] == "stopped"


def test_resource_types_limits_what_is_managed(monkeypatch):
    monkeypatch.setenv("RESOURCE_TYPES", "rds")
    ec2 = boto3.client("ec2", region_name=REGION)
    tagged = _instance(ec2, SCHEDULED)

    result = lf.lambda_handler({"action": "stop"})

    assert "ec2" not in result
    assert _state(ec2, tagged) == "running"


# ------------------------------------------------------------------ Failures


@pytest.mark.parametrize(
    "event",
    [
        {},
        {"action": "reboot"},
        {"function_name": "stop_instances"},
        {"action": "stop", "dry_run": "false"},
    ],
)
def test_invalid_action_raises(event):
    with pytest.raises(ValueError):
        lf.lambda_handler(event)


def test_api_failure_is_raised_not_swallowed(monkeypatch):
    ec2 = boto3.client("ec2", region_name=REGION)
    _instance(ec2, SCHEDULED)

    def boom(**_kwargs):
        raise RuntimeError("UnauthorizedOperation")

    real_client = boto3.client

    def client(service, *args, **kwargs):
        c = real_client(service, *args, **kwargs)
        if service == "ec2":
            monkeypatch.setattr(c, "stop_instances", boom)
        return c

    monkeypatch.setattr(lf.boto3, "client", client)

    with pytest.raises(lf.SchedulerError, match="UnauthorizedOperation"):
        lf.lambda_handler({"action": "stop"})


def test_one_failing_instance_does_not_block_the_rest_of_the_batch(monkeypatch):
    ec2 = boto3.client("ec2", region_name=REGION)
    good = _instance(ec2, SCHEDULED)
    bad = _instance(ec2, SCHEDULED)

    real_client = boto3.client

    def client(service, *args, **kwargs):
        c = real_client(service, *args, **kwargs)
        if service == "ec2":
            real_stop = c.stop_instances

            def stop(InstanceIds):  # noqa: N803 - boto3 argument name
                if bad in InstanceIds:
                    raise RuntimeError("UnsupportedOperation")
                return real_stop(InstanceIds=InstanceIds)

            monkeypatch.setattr(c, "stop_instances", stop)
        return c

    monkeypatch.setattr(lf.boto3, "client", client)

    with pytest.raises(lf.SchedulerError, match=bad):
        lf.lambda_handler({"action": "stop"})
    assert _state(ec2, good) == "stopped"
    assert _state(ec2, bad) == "running"


def test_rds_read_replica_setup_is_skipped():
    rds = boto3.client("rds", region_name=REGION)
    _db(rds, "dev-source", SCHEDULED)
    rds.create_db_instance_read_replica(
        DBInstanceIdentifier="dev-replica",
        SourceDBInstanceIdentifier="dev-source",
        Tags=SCHEDULED,
    )

    assert lf.lambda_handler({"action": "stop"})["rds"]["instances"] == []
