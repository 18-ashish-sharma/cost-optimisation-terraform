module "lambda_function" {
  source        = "terraform-aws-modules/lambda/aws"
  function_name = local.function_name

  handler     = "lambda_function.lambda_handler"
  runtime     = "python3.9"
  source_path = "../../src"

  architectures = ["x86_64"]

  memory_size           = 3008
  timeout               = 120

  tags = {
    Name = local.function_name
  }
  create_role = false
  lambda_role = aws_iam_role.lambda_role.arn
  cloudwatch_logs_retention_in_days  = 5
}
