module "s3" {
  source = "../../modules/s3"

  bucket_name            = var.bucket_name
  enable_versioning      = var.enable_versioning
  enable_eventbridge     = var.enable_eventbridge
  enable_website         = var.enable_website
  website_index_document = var.website_index_document
  website_error_document = var.website_error_document

  # optional fürs einfache Aufräumen in Dev
  force_destroy = var.force_destroy

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets

  cloudfront_distribution_arns = var.cloudfront_distribution_arns

  logs_delivery_source_arn = var.logs_delivery_source_arn
  logs_account_id          = var.logs_account_id
  logs_prefix              = var.logs_prefix

  ses_receipt_rule_arn = var.ses_receipt_rule_arn
  ses_account_id       = var.ses_account_id
  ses_prefix           = var.ses_prefix

  tenant_role_arn    = var.tenant_role_arn
  tenant_tag_pattern = var.tenant_tag_pattern

  tags = var.tags
}

output "bucket_name"      { value = module.s3.bucket_name }
output "bucket_arn"       { value = module.s3.bucket_arn }
output "regional_domain"  { value = module.s3.regional_domain }
output "website_endpoint" { value = module.s3.website_endpoint }
