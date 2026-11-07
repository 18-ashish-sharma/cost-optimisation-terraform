# terraform test: plans the module with dummy credentials. Nothing is created and no AWS
# call is made: the account/region data sources are overridden, and IAM policy documents are
# rendered locally by the provider.
#   cd modules/scheduler && terraform init -backend=false && terraform test

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

override_data {
  target = data.aws_region.current
  values = { region = "ap-south-1" }
}

override_data {
  target = data.aws_partition.current
  values = { partition = "aws" }
}

variables {
  name = "test"
}

run "default_schedules" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_event_rule.schedule) == 2
    error_message = "Expected one rule per schedule (start, stop)."
  }

  assert {
    condition     = aws_cloudwatch_event_rule.schedule["stop"].schedule_expression == "cron(30 14 ? * MON-FRI *)"
    error_message = "Default stop must be 14:30 UTC (20:00 IST) on weekdays."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_event_target.schedule["start"].input).action == "start"
    error_message = "The start rule must send {\"action\": \"start\"}."
  }

  assert {
    condition     = aws_lambda_function.scheduler.memory_size == 128 && aws_lambda_function.scheduler.runtime == "python3.12"
    error_message = "Lambda must stay small (128 MB) on a supported runtime."
  }
}

run "start_stop_is_tag_scoped" {
  command = plan

  assert {
    condition = alltrue([
      for s in jsondecode(data.aws_iam_policy_document.lambda.json).Statement :
      can(s.Condition.StringEquals["aws:ResourceTag/Schedule"])
      if length(regexall("(Start|Stop)", jsonencode(s.Action))) > 0
    ])
    error_message = "Every start/stop statement must be conditioned on the Schedule tag."
  }
}

run "ec2_only_grants_no_rds" {
  command = plan

  variables {
    resource_types = ["ec2"]
  }

  assert {
    condition     = !strcontains(data.aws_iam_policy_document.lambda.json, "rds:")
    error_message = "With resource_types = [ec2] the policy must not grant any rds: action."
  }
}

run "rejects_unknown_action" {
  command = plan

  variables {
    schedules = {
      bad = { action = "reboot", expression = "cron(0 3 ? * MON-FRI *)" }
    }
  }

  expect_failures = [var.schedules]
}
