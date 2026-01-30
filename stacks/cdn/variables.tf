# stacks/cdn/variables.tf

variable "region" {
  description = "Region für Provider (ACM für CloudFront MUSS in us-east-1 sein; CloudFront ist global)"
  type        = string
  default     = "us-east-1"
}

# Route53-Zone, in der die DNS-Validierungs-CNAMEs erstellt werden
variable "zone_name" {
  description = "Öffentliche Hosted Zone, z. B. example.com (mit/ohne trailing dot)"
  type        = string
}

# Domains, für die das Zertifikat gelten soll (erstes Element = Common Name)
variable "certificate_domains" {
  description = "Liste der Domains für das ACM-Zertifikat (CN + SANs), z. B. [\"example.com\", \"www.example.com\"]"
  type        = list(string)
}

# Für Redirect-Function (damit nichts hardcoded ist)
variable "apex_domain" {
  description = "Apex Domain (Root), z.B. example.com"
  type        = string
}

variable "www_domain" {
  description = "WWW Domain, z.B. www.example.com"
  type        = string
}

# Origins für die beiden Distributions
variable "redirect_custom_origin_domain" {
  description = "Dummy/Custom-Origin für die Redirect-Distribution (wird nicht genutzt, da nur Function-Redirect)"
  type        = string
  default     = "example.com"
}

variable "web_s3_origin_domain" {
  description = "S3-REST-Endpoint für die Web-Distribution (z.B. <bucket>.s3.us-east-1.amazonaws.com)"
  type        = string
}
