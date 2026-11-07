output "sns_topic_arn" {
  description = "SNS topic that receives budget and anomaly alerts. Reuse it for other alarms."
  value       = aws_sns_topic.alerts.arn
}

output "budget_name" {
  description = "Name of the monthly AWS Budget."
  value       = aws_budgets_budget.monthly.name
}

output "anomaly_monitor_arn" {
  description = "ARN of the Cost Anomaly Detection monitor, or null when disabled."
  value       = try(aws_ce_anomaly_monitor.services[0].arn, null)
}
