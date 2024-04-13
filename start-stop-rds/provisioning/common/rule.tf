# CloudWatch Event Rule for starting rds instances
resource "aws_cloudwatch_event_rule" "daily_event_start" {
  name                = "lambda-start-rds-trigger-${var.env}"
  schedule_expression = "cron(30 1 * * ? *)" # 7 PM IST daily
  role_arn            = aws_iam_role.lambda_role.arn
}

# CloudWatch Event Target for starting rds instances
resource "aws_cloudwatch_event_target" "lambda_target_start" {
  rule      = aws_cloudwatch_event_rule.daily_event_start.name
  target_id = "start-rds"
  arn       = module.lambda_function.lambda_function_arn

  input = jsonencode({
    function_name = "start_instances"
  })
}

# CloudWatch Event Rule for stopping rds instances
resource "aws_cloudwatch_event_rule" "daily_event_stop" {
  name                = "lambda-stop-rds-trigger-${var.env}"
  schedule_expression = var.schedule_expression_start_rds
  role_arn            = aws_iam_role.lambda_role.arn
}

# CloudWatch Event Target for stopping rds instances
resource "aws_cloudwatch_event_target" "lambda_target_stop" {
  rule      = aws_cloudwatch_event_rule.daily_event_stop.name
  target_id = "stop-rds"
  arn       = module.lambda_function.lambda_function_arn

  input = jsonencode({
    function_name = "stop_instances",
  })
}
