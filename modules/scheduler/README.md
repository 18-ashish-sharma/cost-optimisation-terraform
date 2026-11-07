# Module: scheduler

One Lambda function (Python 3.12, arm64, 128 MB) that starts or stops EC2 instances and
RDS databases tagged `Schedule=true` (configurable), triggered by EventBridge rules.

* `schedules` is a map, so adding a schedule is one map entry: one rule, one target and one
  `aws_lambda_permission` are created per entry with `for_each`.
* IAM is least-privilege: `Describe*` is read-only on `*` (those APIs have no resource-level
  permissions); start/stop is limited to this account and region **and** to resources whose
  tag matches (`aws:ResourceTag/<tag_key>`). Only the services in `resource_types` get permissions.
* A CloudWatch alarm fires when the function reports any error.

```hcl
module "scheduler" {
  source = "../modules/scheduler"

  name           = "cost-opt-dev"
  resource_types = ["ec2", "rds"]
  alarm_actions  = [aws_sns_topic.alerts.arn]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0 |
| archive | >= 2.6, < 3.0 |
| aws | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| archive | >= 2.6, < 3.0 |
| aws | >= 6.0, < 7.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_event_rule.schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.errors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_iam_role.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [archive_file.lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix for every resource in this module, e.g. "cost-scheduler-dev". | `string` | n/a | yes |
| alarm\_actions | ARNs (usually an SNS topic) notified when the Lambda reports an error. Empty list = alarm with no notification. | `list(string)` | `[]` | no |
| log\_retention\_in\_days | CloudWatch Logs retention for the Lambda log group. | `number` | `14` | no |
| memory\_size | Lambda memory in MB. The function only makes AWS API calls, so the minimum is enough. | `number` | `128` | no |
| resource\_types | Which services the Lambda manages. Any of "ec2", "rds". IAM permissions are granted only for the types listed. | `set(string)` | <pre>[<br/>  "ec2",<br/>  "rds"<br/>]</pre> | no |
| schedules | EventBridge schedules, keyed by a short name. Each entry fires the Lambda with {"action": <action>}.<br/>EventBridge rule cron expressions are evaluated in UTC. IST = UTC + 5:30 (no daylight saving). | <pre>map(object({<br/>    action      = string<br/>    expression  = string<br/>    description = optional(string, "")<br/>  }))</pre> | <pre>{<br/>  "start": {<br/>    "action": "start",<br/>    "description": "Start tagged resources at 08:30 IST on weekdays",<br/>    "expression": "cron(0 3 ? * MON-FRI *)"<br/>  },<br/>  "stop": {<br/>    "action": "stop",<br/>    "description": "Stop tagged resources at 20:00 IST on weekdays",<br/>    "expression": "cron(30 14 ? * MON-FRI *)"<br/>  }<br/>}</pre> | no |
| tag\_key | Tag key that opts a resource in to scheduling. | `string` | `"Schedule"` | no |
| tag\_value | Tag value that opts a resource in to scheduling. | `string` | `"true"` | no |
| tags | Tags added to every resource in this module. | `map(string)` | `{}` | no |
| timeout | Lambda timeout in seconds. | `number` | `60` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| errors\_alarm\_name | Name of the CloudWatch alarm on Lambda errors. |
| function\_arn | ARN of the start/stop Lambda function. |
| function\_name | Name of the start/stop Lambda function. |
| log\_group\_name | CloudWatch log group the Lambda writes to. |
| role\_arn | ARN of the Lambda execution role. |
| schedule\_rules | EventBridge rule name and expression, keyed by schedule name. |
<!-- END_TF_DOCS -->
