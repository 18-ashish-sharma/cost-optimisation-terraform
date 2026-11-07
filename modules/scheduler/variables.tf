variable "name" {
  type        = string
  description = "Name prefix for every resource in this module, e.g. \"cost-scheduler-dev\"."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]{1,40}$", var.name))
    error_message = "name must be 1-40 characters: letters, digits, '-' or '_'."
  }
}

variable "resource_types" {
  type        = set(string)
  description = "Which services the Lambda manages. Any of \"ec2\", \"rds\". IAM permissions are granted only for the types listed."
  default     = ["ec2", "rds"]

  validation {
    condition     = length(var.resource_types) > 0 && alltrue([for t in var.resource_types : contains(["ec2", "rds"], t)])
    error_message = "resource_types must be a non-empty subset of [\"ec2\", \"rds\"]."
  }
}

variable "schedules" {
  description = <<-EOT
    EventBridge schedules, keyed by a short name. Each entry fires the Lambda with {"action": <action>}.
    EventBridge rule cron expressions are evaluated in UTC. IST = UTC + 5:30 (no daylight saving).
  EOT
  type = map(object({
    action      = string
    expression  = string
    description = optional(string, "")
  }))
  default = {
    stop = {
      action      = "stop"
      expression  = "cron(30 14 ? * MON-FRI *)" # 14:30 UTC = 20:00 IST, Mon-Fri
      description = "Stop tagged resources at 20:00 IST on weekdays"
    }
    start = {
      action      = "start"
      expression  = "cron(0 3 ? * MON-FRI *)" # 03:00 UTC = 08:30 IST, Mon-Fri
      description = "Start tagged resources at 08:30 IST on weekdays"
    }
  }

  validation {
    condition     = alltrue([for s in values(var.schedules) : contains(["start", "stop"], s.action)])
    error_message = "Each schedule's action must be \"start\" or \"stop\"."
  }

  validation {
    condition     = alltrue([for s in values(var.schedules) : can(regex("^(cron|rate)\\(.+\\)$", s.expression))])
    error_message = "Each schedule's expression must be cron(...) or rate(...)."
  }
}

variable "tag_key" {
  type        = string
  description = "Tag key that opts a resource in to scheduling."
  default     = "Schedule"
}

variable "tag_value" {
  type        = string
  description = "Tag value that opts a resource in to scheduling."
  default     = "true"
}

variable "memory_size" {
  type        = number
  description = "Lambda memory in MB. The function only makes AWS API calls, so the minimum is enough."
  default     = 128
}

variable "timeout" {
  type        = number
  description = "Lambda timeout in seconds."
  default     = 60
}

variable "log_retention_in_days" {
  type        = number
  description = "CloudWatch Logs retention for the Lambda log group."
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_in_days)
    error_message = "log_retention_in_days must be a value CloudWatch Logs accepts (1, 3, 5, 7, 14, 30, ...)."
  }
}

variable "alarm_actions" {
  type        = list(string)
  description = "ARNs (usually an SNS topic) notified when the Lambda reports an error. Empty list = alarm with no notification."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags added to every resource in this module."
  default     = {}
}
