data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  function_name = "${var.name}-start-stop"
  # e.g. arn:aws:ec2:ap-south-1:123456789012 -- resolved at plan time, never hard-coded.
  ec2_arn_prefix = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}"
  rds_arn_prefix = "arn:${data.aws_partition.current.partition}:rds:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}"
}

# ---------------------------------------------------------------- Lambda code

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/src/lambda_function.py"
  output_path = "${path.module}/builds/${local.function_name}.zip"
}

# ---------------------------------------------------------------- Logs

resource "aws_cloudwatch_log_group" "lambda" {
  #checkov:skip=CKV_AWS_158:Logs hold resource IDs only; the default CloudWatch encryption is sufficient. Pass a KMS key if your policy needs one.
  #checkov:skip=CKV_AWS_338:Short retention is deliberate in a cost-optimisation stack; operational logs, not audit logs.
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

# ---------------------------------------------------------------- Function

resource "aws_lambda_function" "scheduler" {
  #checkov:skip=CKV_AWS_117:Calls only public AWS APIs; a VPC would add NAT/endpoint cost and no isolation benefit.
  #checkov:skip=CKV_AWS_116:Invoked by schedule; failures raise and trip the Errors alarm, and the next schedule re-runs idempotently. A DLQ adds no recovery path.
  #checkov:skip=CKV_AWS_115:Reserved concurrency fails on accounts with a low concurrency quota; two rules firing hours apart cannot overlap meaningfully.
  #checkov:skip=CKV_AWS_272:Code signing is out of scope for a single-file function deployed from this repo by CI-reviewed PRs.
  #checkov:skip=CKV_AWS_173:Environment variables hold only tag names and resource types, no secrets.
  #checkov:skip=CKV_AWS_50:X-Ray tracing not needed for a short batch job; structured JSON logs cover it.
  function_name    = local.function_name
  description      = "Start/stop ${join(", ", sort(tolist(var.resource_types)))} resources tagged ${var.tag_key}=${var.tag_value}"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  architectures    = ["arm64"] # Graviton: lower price per GB-second than x86_64
  memory_size      = var.memory_size
  timeout          = var.timeout
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      TAG_KEY        = var.tag_key
      TAG_VALUE      = var.tag_value
      RESOURCE_TYPES = join(",", sort(tolist(var.resource_types)))
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy.lambda]
}

# ---------------------------------------------------------------- Schedules

resource "aws_cloudwatch_event_rule" "schedule" {
  for_each = var.schedules

  name                = "${var.name}-${each.key}"
  description         = each.value.description
  schedule_expression = each.value.expression
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "schedule" {
  for_each = var.schedules

  rule      = aws_cloudwatch_event_rule.schedule[each.key].name
  target_id = "${var.name}-${each.key}"
  arn       = aws_lambda_function.scheduler.arn
  input     = jsonencode({ action = each.value.action })
}

# Resource-based policy: lets each EventBridge rule (and only that rule) invoke the function.
resource "aws_lambda_permission" "schedule" {
  for_each = var.schedules

  statement_id  = "AllowEventBridge-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule[each.key].arn
}

# ---------------------------------------------------------------- Failure alerting

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${local.function_name}-errors"
  alarm_description   = "The start/stop Lambda failed at least once. Check log group ${aws_cloudwatch_log_group.lambda.name}."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.scheduler.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  tags                = var.tags
}
