# Module: IAM-Lambda-Universal


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}


# Inputs

variable "role_name" {
  type        = string
  description = "Eindeutiger Name der IAM-Rolle"

  validation {
    # trim entfernt Leerzeichen am Anfang/Ende für einen sauberen Check
    condition     = length(trim(var.role_name, " ")) > 0
    error_message = "Der role_name darf nicht leer sein oder nur aus Leerzeichen bestehen."
  }
}

variable "role_path" {
  type        = string
  default     = "/service-role/"
  description = "IAM-Pfad (Standardmäßig für Service-Rollen)"
}

variable "policy_arns" {
  type        = list(string)
  default     = []
  description = "Liste von Managed Policy ARNs (z.B. AWSLambdaBasicExecutionRole)"
}

variable "tags" {
  type    = map(string)
  default = {}
}


# Trust Policy (Lambda)

data "aws_iam_policy_document" "trust_lambda" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}


# IAM Role

resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust_lambda.json
  tags               = var.tags
}


# Attach Managed Policies

resource "aws_iam_role_policy_attachment" "attached" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}


# Outputs

output "role_name" {
  description = "Der Name der erstellten Rolle"
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "Der ARN der erstellten Rolle"
  value       = aws_iam_role.this.arn
}
