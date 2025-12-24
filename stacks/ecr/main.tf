module "ecr" {
  source = "../../modules/ecr"

  repository_name       = var.repository_name
  kms_key_arn           = var.kms_key_arn
  scan_on_push          = var.scan_on_push
  image_tag_mutability  = var.image_tag_mutability
  lifecycle_policy_json = var.lifecycle_policy_json
  tags                  = var.tags
}

output "repository_name" { value = module.ecr.repository_name }
output "repository_arn"  { value = module.ecr.repository_arn }
output "repository_url"  { value = module.ecr.repository_url }
