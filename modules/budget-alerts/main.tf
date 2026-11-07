data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------- Alert topic

resource "aws_sns_topic" "alerts" {
  #checkov:skip=CKV_AWS_26:AWS Budgets cannot publish to a topic encrypted with the AWS-managed SNS key; a customer-managed key is a follow-up. Messages contain spend figures only.
  name = "${var.name}-cost-alerts"
  tags = var.tags
}

# Allow AWS Budgets, Cost Anomaly Detection and CloudWatch alarms to publish -- only on behalf of this account.
data "aws_iam_policy_document" "alerts" {
  statement {
    sid       = "AllowAlertServicesPublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com", "costalerts.amazonaws.com", "cloudwatch.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# ---------------------------------------------------------------- Monthly budget

resource "aws_budgets_budget" "monthly" {
  name         = "${var.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_limit_amount)
  limit_unit   = var.currency
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = var.thresholds
    content {
      comparison_operator       = "GREATER_THAN"
      threshold                 = notification.value.percent
      threshold_type            = "PERCENTAGE"
      notification_type         = notification.value.type
      subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
    }
  }

  tags = var.tags

  depends_on = [aws_sns_topic_policy.alerts]
}

# ---------------------------------------------------------------- Cost Anomaly Detection (optional)

resource "aws_ce_anomaly_monitor" "services" {
  count = var.enable_anomaly_detection ? 1 : 0

  name              = "${var.name}-services"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
  tags              = var.tags
}

resource "aws_ce_anomaly_subscription" "alerts" {
  count = var.enable_anomaly_detection ? 1 : 0

  name             = "${var.name}-anomalies"
  frequency        = "IMMEDIATE" # SNS subscribers require IMMEDIATE
  monitor_arn_list = [aws_ce_anomaly_monitor.services[0].arn]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.alerts.arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_threshold_amount)]
    }
  }

  tags = var.tags

  depends_on = [aws_sns_topic_policy.alerts]
}
