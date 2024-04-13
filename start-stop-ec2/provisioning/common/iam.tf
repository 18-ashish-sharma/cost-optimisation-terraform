resource "aws_iam_role" "lambda_role" {
  name               = "lambda-role-start-stop-ec2-${var.env}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action    = "sts:AssumeRole"
      },
      {
        Effect    = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy for Lambda Role
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-policy-start-stop-ec2-${var.env}"
  description = "Policy for Lambda Function"
  policy      = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:ap-south-1:${var.account_number}:*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "ec2:*"
        ]
        Resource = "*"
      },
      {
            Effect = "Allow",
            Action = [
                "lambda:InvokeFunction"
            ],
            Resource = [
                "arn:aws:lambda:ap-south-1:569197888283:function:core-lambda-start-stop-ec2-${var.env}:*",
                "arn:aws:lambda:ap-south-1:569197888283:function:core-lambda-start-stop-ec2-${var.env}"
            ]
        }
    ]
  })
}

# Attach Policy to IAM Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_role.name
}