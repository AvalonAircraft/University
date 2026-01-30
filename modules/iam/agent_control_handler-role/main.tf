# Module: IAM-Lambda-Control-Handler


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# ... (Data Sources & Inputs bleiben wie von dir definiert) ...


# Trust Policy (Lambda)

data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}


# Role

resource "aws_iam_role" "this" {
  name                 = var.role_name
  path                 = var.role_path
  assume_role_policy   = data.aws_iam_policy_document.assume_lambda.json
  max_session_duration = 3600
  tags                 = var.tags
}


# Policy Attachments


# Attachment der kundenverwalteten Basic Logs Policy
resource "aws_iam_role_policy_attachment" "basic_logs" {
  role       = aws_iam_role.this.name
  policy_arn = local.basic_logs_policy_arn
}


# Inline Policy: VPC & ELB Connectivity

data "aws_iam_policy_document" "network_access" {
  statement {
    sid    = "VpcEniAccess"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ElbDiscovery"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "network" {
  name   = "Lambda_Network_Connectivity"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.network_access.json
}


# Inline Policy: Data Access (S3 & KMS)

data "aws_iam_policy_document" "data_access" {
  statement {
    sid    = "ReadEmailFromS3"
    effect = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}/*"
    ]
  }

  statement {
    sid    = "KmsDecryptForS3"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "data" {
  name   = "Lambda_Data_Access"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.data_access.json
}


# Outputs

output "role_arn"  { value = aws_iam_role.this.arn }
output "role_name" { value = aws_iam_role.this.name }
