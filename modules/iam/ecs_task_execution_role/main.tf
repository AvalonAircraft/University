# Module: IAM-ECS-Task-Execution-Role


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

data "aws_partition" "current" {}


# Inputs

variable "role_name" {
  type        = string
  description = "Name of the execution role (e.g. ecsTaskExecutionRole)"

  validation {
    # Trim entfernt Leerzeichen, um sicherzustellen, dass nicht nur " " übergeben wird
    condition     = length(trim(var.role_name, " ")) > 0
    error_message = "Der role_name darf nicht leer sein."
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

variable "extra_policy_arns" {
  type        = list(string)
  default     = []
  description = "List of ARNs for additional managed policies (e.g. SecretManager access)"
}


# Trust Policy (ECS)

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


# Standard AWS Policy für ECS Execution (Logs + ECR)
resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Dynamische Zuweisung zusätzlicher Policies (z.B. für Secrets oder Parameter Store)
resource "aws_iam_role_policy_attachment" "extra" {
  for_each   = toset(var.extra_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}


# Outputs

output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn }
