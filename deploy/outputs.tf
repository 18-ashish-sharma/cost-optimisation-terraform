output "workspace" {
  description = "Terraform workspace (environment) this state belongs to."
  value       = terraform.workspace
}

output "scheduler_function_name" {
  description = "Lambda to invoke for a manual run (see README)."
  value       = module.scheduler.function_name
}

output "scheduler_log_group" {
  description = "CloudWatch log group for the scheduler Lambda."
  value       = module.scheduler.log_group_name
}

output "schedule_rules" {
  description = "EventBridge rules and their cron expressions."
  value       = module.scheduler.schedule_rules
}

output "alerts_sns_topic_arn" {
  description = "SNS topic for budget, anomaly and Lambda-failure alerts."
  value       = module.budget_alerts.sns_topic_arn
}

output "budget_name" {
  description = "Name of the monthly AWS Budget."
  value       = module.budget_alerts.budget_name
}
