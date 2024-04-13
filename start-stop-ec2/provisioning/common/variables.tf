variable "env" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "function_name" {
  type    = string
  default = "core-lambda-start-stop-ec2"
}

variable "account_number" {
  default = ""
}

variable "schedule_expression_start_ec2" {
  default = "cron(30 1 * * ? *)" # 10 PM IST daily
}