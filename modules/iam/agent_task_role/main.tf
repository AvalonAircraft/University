# Module: IAM-ECS-Task-KI-Agent


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# ... (Data Sources bleiben identisch) ...


# Locals

locals {
  # EventBridge Bus ARN Logik
  event_bus_arn = var.event_bus_arn != "" ? var.event_bus_arn : "arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/${var.event_bus_name}"

  # Bedrock Model ARN - Foundation Models sind oft global oder regionsspezifisch ohne Account-ID
  bedrock_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.name}::foundation-model/${var.bedrock_model_id}"
}


# Trust Policy (ECS Tasks)

data "aws_iam_policy_document" "assume_ecs_tasks" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}


# Role

resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
  tags               = var.tags
}


# Managed Policy Attachments

# Ermöglicht dem Agenten das Senden von Events und vollen Log-Zugriff
resource "aws_iam_role_policy_attachment" "managed_attachments" {
  for_each = toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEventBridgeFullAccess",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchFullAccess"
  ])
  role       = aws_iam_role.this.name
  policy_arn = each.value
}


# Inline Policy: KI-Agent-Intelligence

data "aws_iam_policy_document" "ki_agent" {
  # 1. Bedrock - Das Gehirn
  statement {
    sid    = "BedrockInference"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = [local.bedrock_model_arn]
  }

  # 2. Comprehend - NLP Analyse (optional)
  statement {
    sid       = "ComprehendAnalysis"
    effect    = "Allow"
    actions   = ["comprehend:Detect*"]
    resources = ["*"]
  }

  # 3. S3 & KMS - Input-Daten (Mails/Assets)
  statement {
    sid    = "S3KmsReadAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}",
      "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}/*"
    ]
  }

  statement {
    sid    = "KmsDecryptAccess"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }

  # 4. EventBridge - Feedback an das System
  statement {
    sid       = "EventBridgePutEvents"
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [local.event_bus_arn]
  }
}

resource "aws_iam_role_policy" "ki_agent_inline" {
  name   = "KI-Agent-Permissions"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.ki_agent.json
}


# Outputs

output "role_arn"  { value = aws_iam_role.this.arn }
output "role_name" { value = aws_iam_role.this.name }
