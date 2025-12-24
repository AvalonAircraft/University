#########################################
# inputs (modul-lokal, keine festen ARNs)
#########################################

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID, in der DKIM/DMARC/Verification Records angelegt werden"
  type        = string
}

variable "domain_identities" {
  description = "Domains, die ich in SES verifizieren will (Easy DKIM)"
  type        = list(string)
  default     = []
}

variable "email_identities" {
  description = "Einzelne E-Mail-Identitäten (z.B. ceo@miraedrive.com)"
  type        = list(string)
  default     = []
}

variable "create_receipt" {
  description = "Ob ein Receipt-Rule-Set + Rule für S3-Ablage erstellt wird"
  type        = bool
  default     = true
}

variable "set_active_rule_set" {
  description = "Wenn true, wird das angelegte Rule-Set als aktiv gesetzt"
  type        = bool
  default     = true
}

variable "receipt_rule_set_name" {
  description = "Name des SES Receipt Rule Sets (Region der SES-API, z.B. us-east-1)"
  type        = string
  default     = "default-rule-set"
}

variable "receipt_rule_name" {
  description = "Name der SES Receipt Rule im Set"
  type        = string
  default     = "store-in-s3"
}

variable "s3_bucket_name" {
  description = "Bucket für eingehende E-Mails (ohne s3://)"
  type        = string
}

variable "s3_object_prefix" {
  description = "Prefix für eingehende Mails (z.B. 'emails/' oder 'tenants/_unknown/emails/')"
  type        = string
  default     = "emails/"
}

variable "kms_key_arn" {
  description = "Optionaler KMS Key ARN für S3-Verschlüsselung der E-Mails (leer = keine KMS-Verschl.)"
  type        = string
  default     = ""
}

variable "create_bucket_policy" {
  description = "Erstellt/verwaltet eine S3-Bucket-Policy, damit SES in den Bucket schreiben darf"
  type        = bool
  default     = true
}

variable "dmarc_policy" {
  description = "DMARC Policy (none, quarantine, reject)"
  type        = string
  default     = "none"
  validation {
    condition     = contains(["none","quarantine","reject"], var.dmarc_policy)
    error_message = "dmarc_policy muss one of: none|quarantine|reject sein."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Optionale Tags"
}

#########################################
# Env
#########################################
data "aws_partition"       "current" {}
data "aws_caller_identity" "current" {}
data "aws_region"          "current" {}

locals {
  bucket_arn        = "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}"
  bucket_objects_arn= "${local.bucket_arn}/${trim(var.s3_object_prefix, "/") != "" ? trim(var.s3_object_prefix, "/") : ""}*"
}

#########################################
# SES domain identities (classic API)
#########################################

# Domain-Identitäten
resource "aws_ses_domain_identity" "domains" {
  for_each = toset(var.domain_identities)
  domain   = each.value
}

# Verifikation per _amazonses TXT (notwendig für Domain-Identity)
resource "aws_route53_record" "domain_verification" {
  for_each = aws_ses_domain_identity.domains

  zone_id = var.hosted_zone_id
  name    = "_amazonses.${each.value.domain}"
  type    = "TXT"
  ttl     = 300
  records = [each.value.verification_token]
}

# Easy DKIM Tokens je Domain
resource "aws_ses_domain_dkim" "dkim" {
  for_each = aws_ses_domain_identity.domains
  domain   = each.value.domain
}

# DKIM CNAMEs (3 pro Domain)
resource "aws_route53_record" "dkim_cname_1" {
  for_each = aws_ses_domain_dkim.dkim
  zone_id  = var.hosted_zone_id
  name     = "${each.value.dkim_tokens[0]}._domainkey.${each.key}"
  type     = "CNAME"
  ttl      = 300
  records  = ["${each.value.dkim_tokens[0]}.dkim.amazonses.com"]
}
resource "aws_route53_record" "dkim_cname_2" {
  for_each = aws_ses_domain_dkim.dkim
  zone_id  = var.hosted_zone_id
  name     = "${each.value.dkim_tokens[1]}._domainkey.${each.key}"
  type     = "CNAME"
  ttl      = 300
  records  = ["${each.value.dkim_tokens[1]}.dkim.amazonses.com"]
}
resource "aws_route53_record" "dkim_cname_3" {
  for_each = aws_ses_domain_dkim.dkim
  zone_id  = var.hosted_zone_id
  name     = "${each.value.dkim_tokens[2]}._domainkey.${each.key}"
  type     = "CNAME"
  ttl      = 300
  records  = ["${each.value.dkim_tokens[2]}.dkim.amazonses.com"]
}

# DMARC TXT pro Domain (minimal)
resource "aws_route53_record" "dmarc" {
  for_each = aws_ses_domain_identity.domains
  zone_id  = var.hosted_zone_id
  name     = "_dmarc.${each.value.domain}"
  type     = "TXT"
  ttl      = 300
  records  = ["\"v=DMARC1; p=${var.dmarc_policy};\""]
}

#########################################
# E-Mail Identitäten (classic)
#########################################

resource "aws_ses_email_identity" "emails" {
  for_each = toset(var.email_identities)
  email    = each.value
}

#########################################
# Optional: Bucket-Policy für SES (Inbound)
#########################################
data "aws_iam_policy_document" "ses_put_to_s3" {
  count = var.create_bucket_policy ? 1 : 0

  statement {
    sid     = "AllowSESPuts"
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    resources = [
      local.bucket_objects_arn
    ]

    # Empfohlene Bedingung: Nur aus meinem Account
    condition {
      test     = "StringEquals"
      variable = "aws:Referer"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "ses" {
  count  = var.create_bucket_policy ? 1 : 0
  bucket = var.s3_bucket_name
  policy = data.aws_iam_policy_document.ses_put_to_s3[0].json
}

#########################################
# Receipt Rule Set + Rule (S3)
#########################################

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
  recipients    = [] # leer = alle Empfänger

  s3_action {
    position          = 1
    bucket_name       = var.s3_bucket_name
    object_key_prefix = var.s3_object_prefix
    kms_key_arn       = length(var.kms_key_arn) > 0 ? var.kms_key_arn : null
  }

  depends_on = [aws_ses_receipt_rule_set.this]
}

# Optional: Rule-Set aktivieren
resource "aws_ses_active_receipt_rule_set" "active" {
  count          = var.create_receipt && var.set_active_rule_set ? 1 : 0
  rule_set_name  = aws_ses_receipt_rule_set.this[0].rule_set_name
  depends_on     = [aws_ses_receipt_rule.store_to_s3]
}

#########################################
# outputs
#########################################

output "domain_identity_arns" {
  value = { for d, res in aws_ses_domain_identity.domains : d => res.arn }
}

output "email_identity_arns" {
  value = { for e, res in aws_ses_email_identity.emails : e => res.arn }
}

output "receipt_rule_set_name" {
  value = var.create_receipt ? aws_ses_receipt_rule_set.this[0].rule_set_name : null
}

output "receipt_rule_name" {
  value = var.create_receipt ? aws_ses_receipt_rule.store_to_s3[0].name : null
}
