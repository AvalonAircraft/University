# Module: SES-Core-Identities


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# ... (Variablen und Locals bleiben wie von dir definiert) ...


# 1. SES Domain Identities & Route53


resource "aws_ses_domain_identity" "domains" {
  for_each = toset(var.domain_identities)
  domain   = each.value
}

# Verifikationstoken
resource "aws_route53_record" "domain_verification" {
  for_each = aws_ses_domain_identity.domains
  zone_id  = var.hosted_zone_id
  name     = "_amazonses.${each.value.domain}"
  type     = "TXT"
  ttl      = 300
  records  = [each.value.verification_token]
}

# Easy DKIM Setup
resource "aws_ses_domain_dkim" "dkim" {
  for_each = aws_ses_domain_identity.domains
  domain   = each.value.domain
}

# DKIM CNAME Records (Dynamisch 3 pro Domain)
locals {
  # Erzeugt eine flache Liste aus Domain-DKIM Paaren für Route53
  dkim_records = flatten([
    for domain, dkim in aws_ses_domain_dkim.dkim : [
      for token in dkim.dkim_tokens : {
        domain = domain
        token  = token
      }
    ]
  ])
}

resource "aws_route53_record" "dkim_cnames" {
  for_each = { for record in local.dkim_records : "${record.domain}-${record.token}" => record }
  
  zone_id = var.hosted_zone_id
  name    = "${each.value.token}._domainkey.${each.value.domain}"
  type    = "CNAME"
  ttl     = 300
  records = ["${each.value.token}.dkim.amazonses.com"]
}

# DMARC Support
resource "aws_route53_record" "dmarc" {
  for_each = aws_ses_domain_identity.domains
  zone_id  = var.hosted_zone_id
  name     = "_dmarc.${each.value.domain}"
  type     = "TXT"
  ttl      = 300
  records  = ["v=DMARC1; p=${var.dmarc_policy};"]
}


# 2. Inbound Setup: Receipt Rules


resource "aws_ses_receipt_rule_set" "this" {
  count         = var.create_receipt ? 1 : 0
  rule_set_name = var.receipt_rule_set_name
}

resource "aws_ses_receipt_rule" "store_to_s3" {
  count         = var.create_receipt ? 1 : 0
  name          = var.receipt_rule_name
  rule_set_name = aws_ses_receipt_rule_set.this[0].rule_set_name
  enabled       = true
  scan_enabled  = true

  s3_action {
    position          = 1
    bucket_name       = var.s3_bucket_name
    object_key_prefix = var.s3_object_prefix
    kms_key_arn       = var.kms_key_arn != "" ? var.kms_key_arn : null
  }
}

# Aktivierung des Rule Sets
resource "aws_ses_active_receipt_rule_set" "active" {
  count         = var.create_receipt && var.set_active_rule_set ? 1 : 0
  rule_set_name = aws_ses_receipt_rule_set.this[0].rule_set_name
  depends_on    = [aws_ses_receipt_rule.store_to_s3]
}


# Outputs


output "ses_domain_arns" { value = { for k, v in aws_ses_domain_identity.domains : k => v.arn } }
output "receipt_rule_arn" { 
  value = var.create_receipt ? aws_ses_receipt_rule.store_to_s3[0].arn : null 
}
