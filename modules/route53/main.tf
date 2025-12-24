############################
# Inputs
############################
variable "create_zone" { type = bool }
variable "zone_name"   { type = string }

variable "records" {
  description = "DNS records managed by this module"
  type = list(object({
    name    = string                   # "" = Apex (root), or "www", or FQDN
    type    = string                   # A, AAAA, CNAME, MX, TXT, etc.
    ttl     = number                   # 0 for alias
    records = list(string)             # empty for alias
    alias = optional(object({          # for ALB/NLB/CloudFront/etc.
      name                   = string
      zone_id                = string
      evaluate_target_health = bool
    }))
    # Optional routing policies
    set_identifier          = optional(string)
    routing_policy          = optional(string) # WEIGHTED | FAILOVER | LATENCY
    weight                  = optional(number)
    failover_routing_policy = optional(string) # PRIMARY | SECONDARY
    region                  = optional(string) # for LATENCY
  }))
  default = []
}

############################
# Zone (create or lookup)
############################
resource "aws_route53_zone" "this" {
  count   = var.create_zone ? 1 : 0
  name    = var.zone_name
  comment = "Managed locally by Terraform"
}

data "aws_route53_zone" "existing" {
  count        = var.create_zone ? 0 : 1
  name         = var.zone_name
  private_zone = false
}

locals {
  zone_id = var.create_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.existing[0].zone_id
}

############################
# Records
############################
resource "aws_route53_record" "records" {
  for_each = {
    for r in var.records :
    "${r.type}-${(contains(split(".", r.name), var.zone_name) ? r.name : (trim(r.name) == "" ? var.zone_name : "${r.name}.${var.zone_name}"))}-${lookup(r, "set_identifier", "default")}" => r
  }

  zone_id = local.zone_id

  # FQDN-Logik inline (kein custom function-Local nötig)
  name = contains(split(".", each.value.name), var.zone_name)
         ? each.value.name
         : (trim(each.value.name) == "" ? var.zone_name : "${each.value.name}.${var.zone_name}")

  type           = each.value.type
  set_identifier = try(each.value.set_identifier, null)

  dynamic "weighted_routing_policy" {
    for_each = try(each.value.routing_policy, null) == "WEIGHTED" ? [1] : []
    content { weight = try(each.value.weight, 1) }
  }

  dynamic "failover_routing_policy" {
    for_each = try(each.value.routing_policy, null) == "FAILOVER" ? [1] : []
    content { type = try(each.value.failover_routing_policy, "PRIMARY") }
  }

  dynamic "latency_routing_policy" {
    for_each = try(each.value.routing_policy, null) == "LATENCY" ? [1] : []
    content { region = try(each.value.region, "us-east-1") }
  }

  dynamic "alias" {
    for_each = each.value.alias == null ? [] : [each.value.alias]
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }

  ttl     = each.value.alias == null ? each.value.ttl     : null
  records = each.value.alias == null ? each.value.records : null
}

############################
# Outputs
############################
output "zone_id"      { value = local.zone_id }
output "zone_name"    { value = var.zone_name }
output "name_servers" {
  value       = try(aws_route53_zone.this[0].name_servers, null)
  description = "Only populated if the module created the zone"
}
