# terraform test: plans the module with dummy credentials; nothing is created.
#   cd modules/budget-alerts && terraform init -backend=false && terraform test

provider "aws" {
  region                      = "ap-south-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

override_data {
  target = data.aws_caller_identity.current
  values = { account_id = "123456789012" }
}

# The topic ARN is only known after apply; give it a value at plan time so the
# budget's notification blocks can be counted.
override_resource {
  target          = aws_sns_topic.alerts
  override_during = plan
  values          = { arn = "arn:aws:sns:ap-south-1:123456789012:test-cost-alerts" }
}

variables {
  name                 = "test"
  monthly_limit_amount = 100
  alert_emails         = ["platform-alerts@example.com"]
}

run "default_thresholds" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.monthly.notification) == 2
    error_message = "Expected the default 80% ACTUAL and 100% FORECASTED notifications."
  }

  assert {
    condition     = length(aws_ce_anomaly_monitor.services) == 0
    error_message = "Anomaly detection must be off by default (one service monitor per account)."
  }
}

run "anomaly_detection_opt_in" {
  command = plan

  variables {
    enable_anomaly_detection = true
  }

  assert {
    condition     = length(aws_ce_anomaly_subscription.alerts) == 1
    error_message = "enable_anomaly_detection = true must create the subscription."
  }
}

run "rejects_unknown_threshold_type" {
  command = plan

  variables {
    thresholds = [{ percent = 80, type = "MAYBE" }]
  }

  expect_failures = [var.thresholds]
}
