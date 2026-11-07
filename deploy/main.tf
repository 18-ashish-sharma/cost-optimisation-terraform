locals {
  # One deployment per Terraform workspace: dev, staging, ... (see README "Workspaces").
  name = "${var.project}-${terraform.workspace}"
}

module "budget_alerts" {
  source = "../modules/budget-alerts"

  name                     = local.name
  monthly_limit_amount     = var.monthly_budget_amount
  thresholds               = var.budget_thresholds
  alert_emails             = var.alert_emails
  enable_anomaly_detection = var.enable_anomaly_detection
}

module "scheduler" {
  source = "../modules/scheduler"

  name           = local.name
  resource_types = var.resource_types
  schedules      = var.schedules
  tag_key        = var.schedule_tag_key
  tag_value      = var.schedule_tag_value

  # Lambda failures go to the same topic as budget alerts.
  alarm_actions = [module.budget_alerts.sns_topic_arn]
}
