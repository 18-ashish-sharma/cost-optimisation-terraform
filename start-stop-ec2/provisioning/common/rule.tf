# CloudWatch Event Rule for starting EC2 instances
resource "aws_cloudwatch_event_rule" "daily_event_start" {
  name                = "lambda-start-ec2-trigger-${var.env}"
  schedule_expression = "cron(30 1 * * ? *)" # 7 PM IST daily
  role_arn            = aws_iam_role.lambda_role.arn
}

# CloudWatch Event Target for starting EC2 instances
resource "aws_cloudwatch_event_target" "lambda_target_start" {
  rule      = aws_cloudwatch_event_rule.daily_event_start.name
  target_id = "start-ec2"
  arn       = module.lambda_function.lambda_function_arn

  input = jsonencode({
    function_name = "start_instances"
  })
}

# CloudWatch Event Rule for stopping EC2 instances
resource "aws_cloudwatch_event_rule" "daily_event_stop" {
  name                = "lambda-stop-ec2-trigger-${var.env}"
  schedule_expression = var.schedule_expression_start_ec2
  role_arn            = aws_iam_role.lambda_role.arn
}

# CloudWatch Event Target for stopping EC2 instances
resource "aws_cloudwatch_event_target" "lambda_target_stop" {
  rule      = aws_cloudwatch_event_rule.daily_event_stop.name
  target_id = "stop-ec2"
  arn       = module.lambda_function.lambda_function_arn

  input = jsonencode({
    function_name = "stop_instances",
  })
}
