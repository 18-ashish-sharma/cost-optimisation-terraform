# Module: budget-alerts

A monthly AWS Budget for the account with alerts to an SNS topic (and its email
subscribers), plus an optional Cost Anomaly Detection monitor.

* Default thresholds: **80 % of actual** spend and **100 % of forecasted** spend.
* The SNS topic policy lets only `budgets`, `costalerts` and `cloudwatch` publish, and only
  for this account (`aws:SourceAccount`). The topic is reused for the scheduler's error alarm.
* AWS allows one per-service anomaly monitor per account, so `enable_anomaly_detection`
  defaults to `false`.

```hcl
module "budget_alerts" {
  source = "../modules/budget-alerts"

  name                 = "cost-opt-dev"
  monthly_limit_amount = 100
  alert_emails         = ["platform-alerts@example.com"]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0 |
| aws | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0, < 7.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_budgets_budget.monthly](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [aws_ce_anomaly_monitor.services](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_anomaly_monitor) | resource |
| [aws_ce_anomaly_subscription.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_anomaly_subscription) | resource |
| [aws_sns_topic.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| monthly\_limit\_amount | Monthly cost budget for the whole account, in var.currency. | `number` | n/a | yes |
| name | Name prefix for the budget, SNS topic and anomaly monitor. | `string` | n/a | yes |
| alert\_emails | Email addresses subscribed to the alert SNS topic. Each must confirm the subscription email from AWS. | `list(string)` | `[]` | no |
| anomaly\_threshold\_amount | Alert on an anomaly only when its total cost impact is at least this amount (USD). | `number` | `50` | no |
| currency | Budget currency. AWS Budgets uses USD for most accounts. | `string` | `"USD"` | no |
| enable\_anomaly\_detection | Create a Cost Anomaly Detection monitor (per AWS service) and subscription. Leave false if the account already has a service monitor: AWS allows only one. | `bool` | `false` | no |
| tags | Tags added to every taggable resource in this module. | `map(string)` | `{}` | no |
| thresholds | Alert thresholds as a percentage of the monthly limit.<br/>ACTUAL fires when real spend crosses the threshold; FORECASTED fires when AWS predicts month-end spend will. | <pre>list(object({<br/>    percent = number<br/>    type    = string<br/>  }))</pre> | <pre>[<br/>  {<br/>    "percent": 80,<br/>    "type": "ACTUAL"<br/>  },<br/>  {<br/>    "percent": 100,<br/>    "type": "FORECASTED"<br/>  }<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| anomaly\_monitor\_arn | ARN of the Cost Anomaly Detection monitor, or null when disabled. |
| budget\_name | Name of the monthly AWS Budget. |
| sns\_topic\_arn | SNS topic that receives budget and anomaly alerts. Reuse it for other alarms. |
<!-- END_TF_DOCS -->
