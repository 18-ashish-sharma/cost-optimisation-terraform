variable "aws_region" {
  type        = string
  description = "AWS region to deploy into. The scheduler only manages resources in this region."
  default     = "ap-south-1"
}

variable "project" {
  type        = string
  description = "Short project name used as the resource name prefix (with the workspace name appended)."
  default     = "cost-opt"
}

variable "tags" {
  type        = map(string)
  description = "Extra tags applied to every resource via provider default_tags (e.g. Owner, CostCentre)."
  default     = {}
}

# ---------------------------------------------------------------- Scheduler

variable "resource_types" {
  type        = set(string)
  description = "Services the scheduler manages: any of \"ec2\", \"rds\"."
  default     = ["ec2", "rds"]
}

variable "schedules" {
  description = "EventBridge schedules (UTC). Defaults: stop 20:00 IST and start 08:30 IST, Monday-Friday."
  type = map(object({
    action      = string
    expression  = string
    description = optional(string, "")
  }))
  default = {
    stop = {
      action      = "stop"
      expression  = "cron(30 14 ? * MON-FRI *)" # 20:00 IST
      description = "Stop tagged resources at 20:00 IST on weekdays"
    }
    start = {
      action      = "start"
      expression  = "cron(0 3 ? * MON-FRI *)" # 08:30 IST
      description = "Start tagged resources at 08:30 IST on weekdays"
    }
  }
}

variable "schedule_tag_key" {
  type        = string
  description = "Tag key that opts a resource in to scheduling."
  default     = "Schedule"
}

variable "schedule_tag_value" {
  type        = string
  description = "Tag value that opts a resource in to scheduling."
  default     = "true"
}

# ---------------------------------------------------------------- Budget alerts

variable "monthly_budget_amount" {
  type        = number
  description = "Monthly account cost budget in USD."
}

variable "budget_thresholds" {
  type = list(object({
    percent = number
    type    = string
  }))
  description = "Budget alert thresholds (percent of the monthly budget; ACTUAL or FORECASTED)."
  default = [
    { percent = 80, type = "ACTUAL" },
    { percent = 100, type = "FORECASTED" },
  ]
}

variable "alert_emails" {
  type        = list(string)
  description = "Email addresses that receive budget, anomaly and Lambda-failure alerts."
  default     = []
}

variable "enable_anomaly_detection" {
  type        = bool
  description = "Create a Cost Anomaly Detection service monitor. AWS allows one per account; leave false if one exists."
  default     = false
}
