# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed (breaking)
- Replaced the duplicated `start-stop-ec2/` and `start-stop-rds/` stacks with one reusable
  module, `modules/scheduler`, and one root, `deploy/`, that uses Terraform workspaces per
  environment. Existing state does not carry over; plan a fresh deploy.
- One Lambda now handles EC2 and RDS. Event payload is `{"action": "start" | "stop"}`.

### Fixed
- RDS Lambda never acted: it read `event["action"]` while EventBridge sent `function_name`,
  and it looked up EC2 instance IDs instead of RDS databases.
- EC2 Lambda swallowed every exception and reported success; it now raises so failures show up
  as Lambda errors and trip a CloudWatch alarm.
- Selection now filters by state, paginates, skips Auto Scaling group members and handles
  Aurora clusters at cluster level. Empty result sets are a no-op.
- Schedule comments did not match the cron (01:30 UTC is 07:00 IST, not 19:00/22:00). Both
  schedules are now variables with correct IST comments; defaults are 20:00 stop, 08:30 start, Mon-Fri.
- Removed a hard-coded AWS account ID and region from IAM ARNs.

### Security
- IAM narrowed from `ec2:*` / `rds:*` on `*` to Describe plus Start/Stop, with start/stop
  conditioned on `aws:ResourceTag/Schedule`.
- EventBridge invokes the Lambda via `aws_lambda_permission` scoped to each rule; removed
  `events.amazonaws.com` from the role trust policy.

### Added
- `modules/budget-alerts`: monthly AWS Budget with 80 % actual / 100 % forecast alerts to
  SNS + email, and optional Cost Anomaly Detection.
- CI workflow: fmt, validate, tflint, Checkov (SARIF), ruff and pytest. Removed the old
  time-of-day workflow, `check_version.sh` and `version.properties`.
- Lambda memory 3008 MB -> 128 MB, runtime python3.9 -> python3.12, arm64.

## [5.0.2] - 2024-04-15
### Changed
- Updated user response.
