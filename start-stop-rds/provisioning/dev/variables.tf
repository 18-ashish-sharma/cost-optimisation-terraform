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
  default = "core-lambda"
}

variable "account_number" {
  default = ""
}

variable "default_tags" {
  default = {
    Environment = "dev"
  }
}

variable "region" {
  default = "ap-south-1"
}

variable "schedule_expression_start_rds" {
  default = "cron(30 1 ? * MON-SAT *)" # 10:00 PM IST daily, Monday through Saturday
}
