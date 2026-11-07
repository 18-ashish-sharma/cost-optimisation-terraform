data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "lambda" {
  # Write logs only to this function's own log group.
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${local.log_group_arn}:*"]
  }

  # Describe* calls do not support resource-level permissions, so they need "*". They are read-only.
  dynamic "statement" {
    for_each = contains(var.resource_types, "ec2") ? [1] : []
    content {
      sid       = "DescribeEc2"
      actions   = ["ec2:DescribeInstances"]
      resources = ["*"]
    }
  }

  # Start/stop is allowed only on instances that carry the schedule tag.
  dynamic "statement" {
    for_each = contains(var.resource_types, "ec2") ? [1] : []
    content {
      sid       = "StartStopTaggedEc2"
      actions   = ["ec2:StartInstances", "ec2:StopInstances"]
      resources = ["${local.ec2_arn_prefix}:instance/*"]
      condition {
        test     = "StringEquals"
        variable = "aws:ResourceTag/${var.tag_key}"
        values   = [var.tag_value]
      }
    }
  }

  dynamic "statement" {
    for_each = contains(var.resource_types, "rds") ? [1] : []
    content {
      sid       = "DescribeRds"
      actions   = ["rds:DescribeDBInstances", "rds:DescribeDBClusters"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = contains(var.resource_types, "rds") ? [1] : []
    content {
      sid = "StartStopTaggedRds"
      actions = [
        "rds:StartDBInstance", "rds:StopDBInstance",
        "rds:StartDBCluster", "rds:StopDBCluster",
      ]
      resources = [
        "${local.rds_arn_prefix}:db:*",
        "${local.rds_arn_prefix}:cluster:*",
      ]
      condition {
        test     = "StringEquals"
        variable = "aws:ResourceTag/${var.tag_key}"
        values   = [var.tag_value]
      }
    }
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${local.function_name}-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}
