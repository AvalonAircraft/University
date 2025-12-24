############################
# Data
############################
data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}

############################
# Inputs
############################
variable "role_name" {
  type    = string
  default = "agentTaskRole"

  validation {
    condition     = length(var.role_name) > 0
    error_message = "role_name darf nicht leer sein."
  }
}

variable "role_path" {
  type    = string
  default = "/"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# Inline-Policy Parameter
variable "s3_bucket_name" {
  type        = string
  description = "S3 bucket for agent inputs (e.g. miraedrive-assets)"

  validation {
    condition     = length(var.s3_bucket_name) > 0
    error_message = "s3_bucket_name darf nicht leer sein."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used to decrypt S3 objects"

  validation {
    condition     = length(var.kms_key_arn) > 0
    error_message = "kms_key_arn darf nicht leer sein."
  }
}

# Bedrock Model (foundation model id; wird zum ARN zusammengesetzt)
# Beispiel: anthropic.claude-3-haiku-20240307-v1:0
variable "bedrock_model_id" {
  type    = string
  default = "anthropic.claude-3-haiku-20240307-v1:0"
}

# EventBridge (entweder Name ODER ARN vorgeben)
variable "event_bus_name" {
  type    = string
  default = "event-bus-miraedrive-2"
}

variable "event_bus_arn" {
  type    = string
  default = "" # optional override
}

############################
# Locals
############################
locals {
  event_bus_arn = var.event_bus_arn != "" ? var.event_bus_arn :
    "arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/${var.event_bus_name}"

  bedrock_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.name}::foundation-model/${var.bedrock_model_id}"
}

############################
# Trust Policy (ECS Tasks)
############################
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

############################
# Role
############################
resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
  tags               = var.tags
}

############################
# Attach AWS-managed policies (wie in deiner Rolle)
############################
resource "aws_iam_role_policy_attachment" "eventbridge_full" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEventBridgeFullAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_full" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchFullAccess"
}

############################
# Inline Policy "KI-Agent"
############################
data "aws_iam_policy_document" "ki_agent" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [local.bedrock_model_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["comprehend:Detect*"]
    resources = ["*"]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}/*"
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [
      var.kms_key_arn
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [local.event_bus_arn]
  }
}

resource "aws_iam_role_policy" "ki_agent_inline" {
  name   = "KI-Agent"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.ki_agent.json
}

############################
# Outputs
############################
output "role_name" {
  value = aws_iam_role.this.name
}

output "role_arn" {
  value = aws_iam_role.this.arn
}
