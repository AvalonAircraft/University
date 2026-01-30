terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  effective_account_id = coalesce(nullif(var.account_id, ""), data.aws_caller_identity.current.account_id)
}

module "iam_identity_center" {
  # Wenn enable=false -> Module wird nicht deployed (portable)
  count  = var.enable_identity_center ? 1 : 0
  source = "../../modules/iam-identity-center"

  account_id = local.effective_account_id

  # adminUser (optional)
  admin_user_username     = var.admin_user_username
  admin_user_email        = var.admin_user_email
  admin_user_given_name   = var.admin_user_given_name
  admin_user_family_name  = var.admin_user_family_name
  admin_user_display_name = var.admin_user_display_name

  # ECRPushMinimal (optional)
  ecr_user_username     = var.ecr_user_username
  ecr_user_email        = var.ecr_user_email
  ecr_user_given_name   = var.ecr_user_given_name
  ecr_user_family_name  = var.ecr_user_family_name
  ecr_user_display_name = var.ecr_user_display_name

  # Groups (optional)
  group_admin_name = var.group_admin_name
  group_devs_name  = var.group_devs_name
}
