variable "default_region" {
  description = "Standard-Region für allgemeine Ressourcen (z.B. Route53 Reads)"
  type        = string
  default     = "us-east-1"
}

variable "ses_region" {
  description = "Region, in der SES betrieben wird (Inbound/Identities)"
  type        = string
  default     = "us-east-1"
}

variable "hosted_zone_name" {
  description = "Public Hosted Zone Name (z.B. miraedrive.com)"
  type        = string
}

variable "domain_identities" {
  description = "Domains, die ich in SES verifiziere"
  type        = list(string)
  default     = []
}

variable "email_identities" {
  description = "E-Mail-Adressen, die ich in SES verifiziere"
  type        = list(string)
  default     = []
}

variable "create_receipt" {
  type        = bool
  default     = true
  description = "Receipt Rule Set + Rule erzeugen"
}

variable "receipt_rule_set_name" {
  type        = string
  default     = "aiagent-receive"
}

variable "receipt_rule_name" {
  type        = string
  default     = "analyze_incoming_email"
}

variable "s3_bucket_name" {
  description = "Bucket für eingehende E-Mails"
  type        = string
}

variable "s3_object_prefix" {
  description = "Prefix im Bucket (z.B. emails/)"
  type        = string
  default     = "emails/"
}

variable "kms_key_arn" {
  description = "Optional: KMS Key ARN für S3-Verschlüsselung der E-Mails"
  type        = string
  default     = ""
}

variable "dmarc_policy" {
  description = "DMARC policy (none, quarantine, reject)"
  type        = string
  default     = "none"
}

variable "tags" {
  type        = map(string)
  default     = {TenantID = ""}
}
