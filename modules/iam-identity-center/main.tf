############################
# Module: iam-identity-center
############################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.54"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region"    "current" {}

############################
# Inputs
############################
variable "account_id" { type = string }

# adminUser
variable "admin_user_username"     { type = string }
variable "admin_user_email"        { type = string }
variable "admin_user_given_name"   { type = string }
variable "admin_user_family_name"  { type = string }
variable "admin_user_display_name" { type = string }

# ECRPushMinimal
variable "ecr_user_username"     { type = string }
variable "ecr_user_email"        { type = string }
variable "ecr_user_given_name"   { type = string }
variable "ecr_user_family_name"  { type = string }
variable "ecr_user_display_name" { type = string }

# Group names
variable "group_admin_name" { type = string, default = "AdminGroup" }
variable "group_devs_name"  { type = string, default = "Developers" }

############################
# SSO Instance (home region)
############################
data "aws_ssoadmin_instances" "this" {}

locals {
  # Take the first (and typically only) instance in the region
  instance_arn      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
  partition         = data.aws_partition.current.partition
}

############################
# Users
############################
resource "aws_identitystore_user" "admin" {
  identity_store_id = local.identity_store_id
  user_name         = var.admin_user_username

  name {
    given_name  = var.admin_user_given_name
    family_name = var.admin_user_family_name
  }

  display_name = var.admin_user_display_name

  emails {
    value   = var.admin_user_email
    primary = true
  }
}

resource "aws_identitystore_user" "ecr" {
  identity_store_id = local.identity_store_id
  user_name         = var.ecr_user_username

  name {
    given_name  = var.ecr_user_given_name
    family_name = var.ecr_user_family_name
  }

  display_name = var.ecr_user_display_name

  emails {
    value   = var.ecr_user_email
    primary = true
  }
}

############################
# Groups
############################
resource "aws_identitystore_group" "admin_group" {
  identity_store_id = local.identity_store_id
  display_name      = var.group_admin_name
  description       = "-"
}

resource "aws_identitystore_group" "developers" {
  identity_store_id = local.identity_store_id
  display_name      = var.group_devs_name
  description       = "-"
}

############################
# Group Memberships
############################
resource "aws_identitystore_group_membership" "admin_user_in_admin_group" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.admin_group.group_id
  member_id         = aws_identitystore_user.admin.user_id
}

resource "aws_identitystore_group_membership" "ecr_user_in_devs" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.developers.group_id
  member_id         = aws_identitystore_user.ecr.user_id
}

############################
# Permission Sets
############################
# adminUser => AdministratorAccess
resource "aws_ssoadmin_permission_set" "admin_user" {
  name             = "adminUser"
  description      = "Administrator access"
  instance_arn     = local.instance_arn
  session_duration = "PT1H"
}

resource "aws_ssoadmin_managed_policy_attachment" "admin_user_admin_access" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin_user.arn
  managed_policy_arn = "arn:${local.partition}:iam::aws:policy/AdministratorAccess"
}

# ECRPushMinimal => AmazonEC2ContainerRegistryFullAccess
resource "aws_ssoadmin_permission_set" "ecr_push_minimal" {
  name             = "ECRPushMinimal"
  description      = "ECR full access for image push/pull"
  instance_arn     = local.instance_arn
  session_duration = "PT1H"
}

resource "aws_ssoadmin_managed_policy_attachment" "ecr_push_minimal_full" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.ecr_push_minimal.arn
  managed_policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

############################
# Account Assignments (USER -> Account)
############################
resource "aws_ssoadmin_account_assignment" "assign_admin_user" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin_user.arn
  principal_type     = "USER"
  principal_id       = aws_identitystore_user.admin.user_id
  target_type        = "AWS_ACCOUNT"
  target_id          = var.account_id
}

resource "aws_ssoadmin_account_assignment" "assign_ecr_user" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.ecr_push_minimal.arn
  principal_type     = "USER"
  principal_id       = aws_identitystore_user.ecr.user_id
  target_type        = "AWS_ACCOUNT"
  target_id          = var.account_id
}

############################
# Outputs
############################
output "instance_arn"      { value = local.instance_arn }
output "identity_store_id" { value = local.identity_store_id }

output "user_admin_id"     { value = aws_identitystore_user.admin.user_id }
output "user_ecr_id"       { value = aws_identitystore_user.ecr.user_id }

output "group_admin_id"    { value = aws_identitystore_group.admin_group.group_id }
output "group_devs_id"     { value = aws_identitystore_group.developers.group_id }

output "ps_admin_user_arn" { value = aws_ssoadmin_permission_set.admin_user.arn }
output "ps_ecr_min_arn"    { value = aws_ssoadmin_permission_set.ecr_push_minimal.arn }
