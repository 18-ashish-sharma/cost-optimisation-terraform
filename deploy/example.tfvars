# Example values only. Copy to e.g. dev.tfvars (git-ignored) and edit.
aws_region = "ap-south-1"
project    = "cost-opt"

tags = {
  Owner      = "platform-team"
  CostCentre = "CC-0000"
}

resource_types = ["ec2", "rds"]

schedules = {
  stop = {
    action      = "stop"
    expression  = "cron(30 14 ? * MON-FRI *)" # 20:00 IST Mon-Fri
    description = "Stop tagged resources at 20:00 IST on weekdays"
  }
  start = {
    action      = "start"
    expression  = "cron(0 3 ? * MON-FRI *)" # 08:30 IST Mon-Fri
    description = "Start tagged resources at 08:30 IST on weekdays"
  }
}

monthly_budget_amount = 100
budget_thresholds = [
  { percent = 80, type = "ACTUAL" },
  { percent = 100, type = "FORECASTED" },
]
alert_emails             = ["platform-alerts@example.com"]
enable_anomaly_detection = false
