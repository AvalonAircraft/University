module "iam_identity_center" {
  source = "../../modules/iam-identity-center"

  account_id = var.account_id

  # adminUser
  admin_user_username     = var.admin_user_username
  admin_user_email        = var.admin_user_email
  admin_user_given_name   = var.admin_user_given_name
  admin_user_family_name  = var.admin_user_family_name
  admin_user_display_name = var.admin_user_display_name

  # ECRPushMinimal
  ecr_user_username     = var.ecr_user_username
  ecr_user_email        = var.ecr_user_email
  ecr_user_given_name   = var.ecr_user_given_name
  ecr_user_family_name  = var.ecr_user_family_name
  ecr_user_display_name = var.ecr_user_display_name

  # Groups
  group_admin_name = var.group_admin_name
  group_devs_name  = var.group_devs_name
}
