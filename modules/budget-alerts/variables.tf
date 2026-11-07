variable "name" {
  type        = string
  description = "Name prefix for the budget, SNS topic and anomaly monitor."
}

variable "monthly_limit_amount" {
  type        = number
  description = "Monthly cost budget for the whole account, in var.currency."

  validation {
    condition     = var.monthly_limit_amount > 0
    error_message = "monthly_limit_amount must be greater than 0."
  }
}

variable "currency" {
  type        = string
  description = "Budget currency. AWS Budgets uses USD for most accounts."
  default     = "USD"
}

variable "thresholds" {
  description = <<-EOT
    Alert thresholds as a percentage of the monthly limit.
    ACTUAL fires when real spend crosses the threshold; FORECASTED fires when AWS predicts month-end spend will.
  EOT
  type = list(object({
    percent = number
    type    = string
  }))
  default = [
    { percent = 80, type = "ACTUAL" },
    { percent = 100, type = "FORECASTED" },
  ]

  validation {
    condition     = alltrue([for t in var.thresholds : contains(["ACTUAL", "FORECASTED"], t.type) && t.percent > 0])
    error_message = "Each threshold needs percent > 0 and type ACTUAL or FORECASTED."
  }
}

variable "alert_emails" {
  type        = list(string)
  description = "Email addresses subscribed to the alert SNS topic. Each must confirm the subscription email from AWS."
  default     = []
}

variable "enable_anomaly_detection" {
  type        = bool
  description = "Create a Cost Anomaly Detection monitor (per AWS service) and subscription. Leave false if the account already has a service monitor: AWS allows only one."
  default     = false
}

variable "anomaly_threshold_amount" {
  type        = number
  description = "Alert on an anomaly only when its total cost impact is at least this amount (USD)."
  default     = 50
}

variable "tags" {
  type        = map(string)
  description = "Tags added to every taggable resource in this module."
  default     = {}
}
