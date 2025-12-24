# modules/cloudfront/main.tf
# Generic CloudFront module with S3 (via OAC) or custom origins.

variable "acm_certificate_arn_us_east_1" {
  description = "ACM cert ARN in us-east-1 for HTTPS (required for custom domain aliases)."
  type        = string
}

variable "distributions" {
  description = "Map of CloudFront distributions to create."
  type = map(object({
    aliases                    = list(string)           # ["miraedrive.com"], ["www.miraedrive.com"]
    comment                    = optional(string)
    price_class                = optional(string)       # PriceClass_All | PriceClass_200 | PriceClass_100
    default_cache_policy_id    = optional(string)
    response_headers_policy_id = optional(string)
    waf_web_acl_arn            = optional(string)
    logging = optional(object({
      bucket = string # "logs-bucket.s3.amazonaws.com"
      prefix = string
    }))
    origin = object({
      domain_name  = string       # "bucket.s3.amazonaws.com" or "xxx.elb.amazonaws.com"
      origin_id    = string
      origin_type  = string       # "s3" | "custom"
      origin_path  = optional(string)
      custom_origin_config = optional(object({
        http_port              = number
        https_port             = number
        origin_protocol_policy = string    # "http-only" | "https-only" | "match-viewer"
        origin_ssl_protocols   = list(string)
      }))
    })
    viewer_protocol_policy = optional(string)       # "redirect-to-https" | "https-only" | "allow-all"
    compress               = optional(bool)         # default true
    minimum_ttl            = optional(number)       # default 0
    default_ttl            = optional(number)       # default 86400
    max_ttl                = optional(number)       # default 31536000
  }))
}

locals {
  default_cache_policy_id     = "658327ea-f89d-4fab-a63d-7e88639e58f6" # AWS managed CachingOptimized
  default_response_headers_id = null
}

resource "aws_cloudfront_origin_access_control" "oac" {
  for_each                           = { for k, d in var.distributions : k => d if d.origin.origin_type == "s3" }
  name                               = "${each.key}-oac"
  description                        = "OAC for ${each.key}"
  origin_access_control_origin_type  = "s3"
  signing_behavior                   = "always"
  signing_protocol                   = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  for_each = var.distributions

  enabled             = true
  is_ipv6_enabled     = true
  comment             = try(each.value.comment, null)
  price_class         = try(each.value.price_class, "PriceClass_100")
  default_root_object = null

  aliases = each.value.aliases

  origin {
    domain_name = each.value.origin.domain_name
    origin_id   = each.value.origin.origin_id
    origin_path = try(each.value.origin.origin_path, null)

    dynamic "s3_origin_config" {
      for_each = each.value.origin.origin_type == "s3" ? [1] : []
      content {
        origin_access_identity = null # OAC statt OAI
      }
    }

    dynamic "custom_origin_config" {
      for_each = each.value.origin.origin_type == "custom" ? [1] : []
      content {
        http_port              = each.value.origin.custom_origin_config.http_port
        https_port             = each.value.origin.custom_origin_config.https_port
        origin_protocol_policy = each.value.origin.custom_origin_config.origin_protocol_policy
        origin_ssl_protocols   = each.value.origin.custom_origin_config.origin_ssl_protocols
      }
    }

    origin_shield {
      enabled              = false
      origin_shield_region = null
    }

    origin_access_control_id = (
      each.value.origin.origin_type == "s3"
      ? aws_cloudfront_origin_access_control.oac[each.key].id
      : null
    )
  }

  default_cache_behavior {
    target_origin_id       = each.value.origin.origin_id
    viewer_protocol_policy = try(each.value.viewer_protocol_policy, "redirect-to-https")
    compress               = try(each.value.compress, true)

    cache_policy_id            = try(each.value.default_cache_policy_id, local.default_cache_policy_id)
    response_headers_policy_id = try(each.value.response_headers_policy_id, local.default_response_headers_id)

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    min_ttl     = try(each.value.minimum_ttl, 0)
    default_ttl = try(each.value.default_ttl, 86400)
    max_ttl     = try(each.value.max_ttl, 31536000)
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn_us_east_1
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  dynamic "logging_config" {
    for_each = try(each.value.logging, null) == null ? [] : [each.value.logging]
    content {
      include_cookies = false
      bucket          = logging_config.value.bucket
      prefix          = logging_config.value.prefix
    }
  }

  web_acl_id = try(each.value.waf_web_acl_arn, null)

  tags = {
    Project = "MiraeDrive"
    Stack   = "cdn"
  }
}

output "distribution_domain_names" {
  description = "Map: key -> CloudFront domain name (e.g., dxxxxx.cloudfront.net)"
  value       = { for k, d in aws_cloudfront_distribution.this : k => d.domain_name }
}

output "distribution_hosted_zone_id" {
  description = "Hosted zone ID for CloudFront (use for Route53 alias)"
  value       = "Z2FDTNDATAQYW2"
}
