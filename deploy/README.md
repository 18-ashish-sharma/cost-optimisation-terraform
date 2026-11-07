# Root module: deploy

Wires `modules/budget-alerts` and `modules/scheduler` together for one environment.
The environment is the **Terraform workspace**: resource names and the `Environment` tag use
`terraform.workspace`. See the [main README](../README.md#usage) for init, workspace and apply steps.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0 |
| archive | ~> 2.6 |
| aws | ~> 6.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| budget\_alerts | ../modules/budget-alerts | n/a |
| scheduler | ../modules/scheduler | n/a |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| monthly\_budget\_amount | Monthly account cost budget in USD. | `number` | n/a | yes |
| alert\_emails | Email addresses that receive budget, anomaly and Lambda-failure alerts. | `list(string)` | `[]` | no |
| aws\_region | AWS region to deploy into. The scheduler only manages resources in this region. | `string` | `"ap-south-1"` | no |
| budget\_thresholds | Budget alert thresholds (percent of the monthly budget; ACTUAL or FORECASTED). | <pre>list(object({<br/>    percent = number<br/>    type    = string<br/>  }))</pre> | <pre>[<br/>  {<br/>    "percent": 80,<br/>    "type": "ACTUAL"<br/>  },<br/>  {<br/>    "percent": 100,<br/>    "type": "FORECASTED"<br/>  }<br/>]</pre> | no |
| enable\_anomaly\_detection | Create a Cost Anomaly Detection service monitor. AWS allows one per account; leave false if one exists. | `bool` | `false` | no |
| project | Short project name used as the resource name prefix (with the workspace name appended). | `string` | `"cost-opt"` | no |
| resource\_types | Services the scheduler manages: any of "ec2", "rds". | `set(string)` | <pre>[<br/>  "ec2",<br/>  "rds"<br/>]</pre> | no |
| schedule\_tag\_key | Tag key that opts a resource in to scheduling. | `string` | `"Schedule"` | no |
| schedule\_tag\_value | Tag value that opts a resource in to scheduling. | `string` | `"true"` | no |
| schedules | EventBridge schedules (UTC). Defaults: stop 20:00 IST and start 08:30 IST, Monday-Friday. | <pre>map(object({<br/>    action      = string<br/>    expression  = string<br/>    description = optional(string, "")<br/>  }))</pre> | <pre>{<br/>  "start": {<br/>    "action": "start",<br/>    "description": "Start tagged resources at 08:30 IST on weekdays",<br/>    "expression": "cron(0 3 ? * MON-FRI *)"<br/>  },<br/>  "stop": {<br/>    "action": "stop",<br/>    "description": "Stop tagged resources at 20:00 IST on weekdays",<br/>    "expression": "cron(30 14 ? * MON-FRI *)"<br/>  }<br/>}</pre> | no |
| tags | Extra tags applied to every resource via provider default\_tags (e.g. Owner, CostCentre). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| alerts\_sns\_topic\_arn | SNS topic for budget, anomaly and Lambda-failure alerts. |
| budget\_name | Name of the monthly AWS Budget. |
| schedule\_rules | EventBridge rules and their cron expressions. |
| scheduler\_function\_name | Lambda to invoke for a manual run (see README). |
| scheduler\_log\_group | CloudWatch log group for the scheduler Lambda. |
| workspace | Terraform workspace (environment) this state belongs to. |
<!-- END_TF_DOCS -->
