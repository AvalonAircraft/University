########################################
# 1) ACM-Zertifikat (us-east-1) + DNS-Validation in Route53
########################################

data "aws_route53_zone" "this" {
  name         = var.zone_name
  private_zone = false
}

resource "aws_acm_certificate" "cf" {
  provider                    = aws.us_east_1
  domain_name                 = var.certificate_domains[0]
  subject_alternative_names   = slice(var.certificate_domains, 1, length(var.certificate_domains))
  validation_method           = "DNS"

  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "cf_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cf.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "cf" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cf.arn
  validation_record_fqdns = [for r in aws_route53_record.cf_validation : r.fqdn]
}

########################################
# 2) CloudFront Function für Redirect
########################################
resource "aws_cloudfront_function" "redirect_to_www" {
  name    = "redirect-to-maindomain"
  runtime = "cloudfront-js-1.0"
  comment = "Redirect apex -> www"
  publish = true

  code = <<'JS'
function handler(event) {
  var req = event.request;
  var host = (req.headers.host && req.headers.host.value) || "";
  if (host === "miraedrive.com") {
    var loc = "https://www.miraedrive.com" + (req.uri || "/");
    if (req.querystring && Object.keys(req.querystring).length > 0) {
      var qs = Object.keys(req.querystring).map(function(k){
        var v = req.querystring[k];
        if (!v || !v.value) return "";
        return k + "=" + v.value;
      }).filter(Boolean).join("&");
      if (qs.length > 0) loc += "?" + qs;
    }
    return { statusCode: 301, statusDescription: "Moved Permanently", headers: { location: { value: loc } } };
  }
  return req;
}
JS
}

########################################
# 3) CloudFront Distributions
########################################

data "aws_cloudfront_cache_policy" "use_origin_cache_headers" {
  name = "UseOriginCacheControlHeaders"
}
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "CachingOptimized"
}
data "aws_cloudfront_response_headers_policy" "cors_and_security" {
  name = "CORS-and-SecurityHeadersPolicy"
}

resource "aws_cloudfront_distribution" "redirect_apex" {
  enabled         = false
  is_ipv6_enabled = true
  comment         = "Redirect from miraedrive.com to www.miraedrive.com"
  price_class     = "PriceClass_All"
  http3_enabled   = false
  aliases         = ["miraedrive.com"]

  origin {
    domain_name = var.redirect_custom_origin_domain
    origin_id   = "redirect-origin"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "redirect-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.use_origin_cache_headers.id
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect_to_www.arn
    }
  }

  restrictions { geo_restriction { restriction_type = "none" } }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cf.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [aws_acm_certificate_validation.cf]

  tags = {
    Project = "MiraeDrive"
    Stack   = "cdn"
    Name    = "miraedrive.com"
  }
}

resource "aws_cloudfront_distribution" "web_www" {
  enabled             = false
  is_ipv6_enabled     = true
  http3_enabled       = true
  comment             = "MiraeDrive-Web"
  price_class         = "PriceClass_All"
  default_root_object = "index2.html"
  aliases             = ["www.miraedrive.com"]

  origin {
    domain_name = var.web_s3_origin_domain
    origin_id   = "s3-web-origin"
    s3_origin_config { origin_access_identity = "" }
  }

  default_cache_behavior {
    target_origin_id             = "s3-web-origin"
    viewer_protocol_policy       = "redirect-to-https"
    compress                     = true
    cache_policy_id              = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id   = data.aws_cloudfront_response_headers_policy.cors_and_security.id
    allowed_methods              = ["GET", "HEAD"]
    cached_methods               = ["GET", "HEAD"]
  }

  restrictions { geo_restriction { restriction_type = "none" } }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cf.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [aws_acm_certificate_validation.cf]

  tags = {
    Project = "MiraeDrive"
    Stack   = "cdn"
    Name    = "MiraeDrive-Web"
    TenantID = ""
  }
}

########################################
# 4) Outputs
########################################
output "acm_certificate_arn_us_east_1" {
  value       = aws_acm_certificate_validation.cf.certificate_arn
  description = "Validiertes ACM-Zertifikat (us-east-1)"
}

output "redirect_distribution_domain" { value = aws_cloudfront_distribution.redirect_apex.domain_name }
output "web_distribution_domain"      { value = aws_cloudfront_distribution.web_www.domain_name }
output "cloudfront_zone_id" {
  value       = "Z2FDTNDATAQYW2"
  description = "Hosted Zone ID von CloudFront (für Route53 Alias)"
}
