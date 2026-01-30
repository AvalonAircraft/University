# Hosted Zone auflösen (optional, account-agnostisch)

data "aws_route53_zone" "this" {
  count        = var.enabled ? 1 : 0
  name         = "${trim(var.hosted_zone_name, ".")}."
  private_zone = false
}


# Modul aufrufen – SES strikt in eigener Region (z. B. us-east-1)

module "ses" {
  count  = var.enabled ? 1 : 0
  source = "../../modules/ses"

  providers = {
    aws = aws.use1
  }

  hosted_zone_id    = data.aws_route53_zone.this[0].zone_id
  domain_identities = var.domain_identities
  email_identities  = var.email_identities

  create_receipt        = var.create_receipt
  set_active_rule_set   = true
  receipt_rule_set_name = var.receipt_rule_set_name
  receipt_rule_name     = var.receipt_rule_name

  s3_bucket_name   = var.s3_bucket_name
  s3_object_prefix = var.s3_object_prefix
  kms_key_arn      = var.kms_key_arn

  # Optional: Bucket-Policy im Modul erzeugen
  create_bucket_policy = var.create_bucket_policy

  dmarc_policy = var.dmarc_policy
  tags         = var.tags
}
