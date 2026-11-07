output "function_name" {
  description = "Name of the start/stop Lambda function."
  value       = aws_lambda_function.scheduler.function_name
}

output "function_arn" {
  description = "ARN of the start/stop Lambda function."
  value       = aws_lambda_function.scheduler.arn
}

output "role_arn" {
  description = "ARN of the Lambda execution role."
  value       = aws_iam_role.lambda.arn
}

output "log_group_name" {
  description = "CloudWatch log group the Lambda writes to."
  value       = aws_cloudwatch_log_group.lambda.name
}

output "schedule_rules" {
  description = "EventBridge rule name and expression, keyed by schedule name."
  value = {
    for k, r in aws_cloudwatch_event_rule.schedule : k => {
      name       = r.name
      expression = r.schedule_expression
    }
  }
}

output "errors_alarm_name" {
  description = "Name of the CloudWatch alarm on Lambda errors."
  value       = aws_cloudwatch_metric_alarm.errors.alarm_name
}
