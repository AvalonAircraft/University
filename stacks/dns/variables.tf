variable "region"      { type = string  default = "us-east-1" }
variable "create_zone" { type = bool    default = true }
variable "zone_name"   { type = string  default = "miraedrive.com" }

variable "dns_records" {
  type = list(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = bool
    }))
    set_identifier          = optional(string)
    routing_policy          = optional(string)
    weight                  = optional(number)
    failover_routing_policy = optional(string)
    region                  = optional(string)
  }))

  default = [
    # Apex → CloudFront d2k4hacdwnh0dn.cloudfront.net
    {
      name    = ""
      type    = "A"
      ttl     = 0
      records = []
      alias = {
        name                   = "d2k4hacdwnh0dn.cloudfront.net"
        zone_id                = "Z2FDTNDATAQYW2"
        evaluate_target_health = false
      }
    },
    {
      name    = ""
      type    = "AAAA"
      ttl     = 0
      records = []
      alias = {
        name                   = "d2k4hacdwnh0dn.cloudfront.net"
        zone_id                = "Z2FDTNDATAQYW2"
        evaluate_target_health = false
      }
    },

    # www → CloudFront d1zowsz2669qvg.cloudfront.net
    {
      name    = "www"
      type    = "A"
      ttl     = 0
      records = []
      alias = {
        name                   = "d1zowsz2669qvg.cloudfront.net"
        zone_id                = "Z2FDTNDATAQYW2"
        evaluate_target_health = false
      }
    },
    {
      name    = "www"
      type    = "AAAA"
      ttl     = 0
      records = []
      alias = {
        name                   = "d1zowsz2669qvg.cloudfront.net"
        zone_id                = "Z2FDTNDATAQYW2"
        evaluate_target_health = false
      }
    },

    # MX (Google Workspace)
    {
      name    = ""
      type    = "MX"
      ttl     = 300
      records = [
        "1 ASPMX.L.GOOGLE.COM.",
        "5 ALT1.ASPMX.L.GOOGLE.COM.",
        "5 ALT2.ASPMX.L.GOOGLE.COM.",
        "10 ALT3.ASPMX.L.GOOGLE.COM.",
        "10 ALT4.ASPMX.L.GOOGLE.COM."
      ]
    },

    # TXT (Google site verification)
    {
      name    = ""
      type    = "TXT"
      ttl     = 300
      records = ["\"google-site-verification=0HWqnY-e0txhcL0XeUrYGJfAkqQqLOXH5P16ewcyMiQ\""]
    },

    # ACM Validations
    {
      name    = "_720aac728e9f0d5fd576d37449c2c153"
      type    = "CNAME"
      ttl     = 300
      records = ["_4e7d9468b3a1809df4a2eab7fd93e6d5.xlfgrmvvlj.acm-validations.aws."]
    },
    {
      name    = "_29a60e0680f2f46114ecb3ea4124c724.www"
      type    = "CNAME"
      ttl     = 300
      records = ["_08de3f38d55e6f4f19f63ea330d31bec.xlfgrmvvlj.acm-validations.aws."]
    },

    # SES DKIM (3x)
    {
      name    = "fqxfya4yrecqfdd2xu54a7vza3tchn2h._domainkey"
      type    = "CNAME"
      ttl     = 1800
      records = ["fqxfya4yrecqfdd2xu54a7vza3tchn2h.dkim.amazonses.com"]
    },
    {
      name    = "fsfx2y4z4bqqbnjaexesvjidhttyss5m._domainkey"
      type    = "CNAME"
      ttl     = 1800
      records = ["fsfx2y4z4bqqbnjaexesvjidhttyss5m.dkim.amazonses.com"]
    },
    {
      name    = "on3tl4lfcsmh4obkfqqxbfogbgcjev4g._domainkey"
      type    = "CNAME"
      ttl     = 1800
      records = ["on3tl4lfcsmh4obkfqqxbfogbgcjev4g.dkim.amazonses.com"]
    }
  ]
}
