# stacks/ses/variables.tf (portable)


variable "enabled" {
  description = "Wenn false: SES Stack wird komplett übersprungen (für Deploy ohne Domain/Route53)."
  type        = bool
  default     = false
}

variable "default_region" {
  description = "Standard-Region für allgemeine Ressourcen (z.B. Route53 Reads)."
  type        = string
  default     = "us-east-1"
}

variable "ses_region" {
  description = "Region, in der SES betrieben wird (Inbound/Identities)."
  type        = string
  default     = "us-east-1"
}

variable "hosted_zone_name" {
  description = "Public Hosted Zone Name (z.B. miraedrive.com). Nur nötig wenn enabled=true."
  type        = string
  default     = ""

  validation {
    condition     = var.enabled == false || length(trim(var.hosted_zone_name)) > 0
    error_message = "hosted_zone_name muss gesetzt sein, wenn enabled=true."
  }
}

variable "domain_identities" {
  description = "Domains, die in SES verifiziert werden (z.B. [\"example.com\"])."
  type        = list(string)
  default     = []
}

variable "email_identities" {
  description = "E-Mail-Adressen, die in SES verifiziert werden (optional)."
  type        = list(string)
  default     = []
}

variable "create_receipt" {
  description = "Receipt Rule Set + Rule erzeugen (Inbound)."
  type        = bool
  default     = false

  validation {
    condition     = var.enabled == false || var.create_receipt == false || length(trim(var.s3_bucket_name)) > 0
    error_message = "Wenn enabled=true und create_receipt=true, muss s3_bucket_name gesetzt sein."
  }
}

variable "receipt_rule_set_name" {
  type        = string
  default     = "aiagent-receive"
  description = "Name des Receipt Rule Sets."
}

variable "receipt_rule_name" {
  type        = string
  default     = "analyze_incoming_email"
  description = "Name der Receipt Rule."
}

variable "s3_bucket_name" {
  description = "Bucket für eingehende E-Mails (nur nötig wenn enabled=true und create_receipt=true)."
  type        = string
  default     = ""
}

variable "s3_object_prefix" {
  description = "Prefix im Bucket (z.B. emails/)."
  type        = string
  default     = "emails/"
}

variable "kms_key_arn" {
  description = "Optional: KMS Key ARN für Verschlüsselung."
  type        = string
  default     = ""
}

variable "create_bucket_policy" {
  description = "Wenn true: Modul erzeugt/managed eine Bucket Policy für SES Zugriff (nur sinnvoll mit create_receipt=true)."
  type        = bool
  default     = true
}

variable "dmarc_policy" {
  description = "DMARC policy (none, quarantine, reject)."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "quarantine", "reject"], lower(trim(var.dmarc_policy)))
    error_message = "dmarc_policy muss one of: none, quarantine, reject sein."
  }
}

variable "tags" {
  type = map(string)
  default = {
    Project  = "University"
    Stack    = "ses"
    TenantID = ""
  }
}
