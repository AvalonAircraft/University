# Module: Route53-DNS


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}


# Inputs


variable "create_zone" { 
  type        = bool 
  description = "True erstellt eine neue Zone, False sucht nach einer existierenden."
}

variable "zone_name" { 
  type        = string 
  description = "Domainname (z.B. miraedrive.com)"
}

variable "records" {
  description = "Liste der DNS-Einträge"
  type = list(object({
    name    = string
    type    = string
    ttl     = optional(number, 300)
    records = optional(list(string), [])
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = bool
    }))
    set_identifier          = optional(string)
    routing_policy          = optional(string) # WEIGHTED | FAILOVER | LATENCY
    weight                  = optional(number)
    failover_routing_policy = optional(string) # PRIMARY | SECONDARY
    region                  = optional(string) # für LATENCY
  }))
  default = []
}


# Zone Management


resource "aws_route53_zone" "this" {
  count   = var.create_zone ? 1 : 0
  name    = var.zone_name
  comment = "Managed by Terraform - MiraeDrive Infrastructure"
}

data "aws_route53_zone" "existing" {
  count        = var.create_zone ? 0 : 1
  name         = var.zone_name
  private_zone = false
}

locals {
  zone_id = var.create_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.existing[0].zone_id
}


# DNS Records


resource "aws_route53_record" "records" {
  for_each = {
    for r in var.records :
    "${r.type}-${r.name == "" ? "@" : r.name}-${lookup(r, "set_identifier", "default")}" => r
  }

  zone_id = local.zone_id

  # Korrekte FQDN-Behandlung: Verhindert doppelte Domain-Endungen
  name = (
    trim(each.value.name, ".") == "" || trim(each.value.name, ".") == var.zone_name 
    ? var.zone_name 
    : (endswith(each.value.name, var.zone_name) ? each.value.name : "${each.value.name}.${var.zone_name}")
  )

  type           = each.value.type
  set_identifier = each.value.set_identifier

  # Routing Policies
  dynamic "weighted_routing_policy" {
    for_each = each.value.routing_policy == "WEIGHTED" ? [1] : []
    content { weight = coalesce(each.value.weight, 100) }
  }

  dynamic "failover_routing_policy" {
    for_each = each.value.routing_policy == "FAILOVER" ? [1] : []
    content { type = coalesce(each.value.failover_routing_policy, "PRIMARY") }
  }

  dynamic "latency_routing_policy" {
    for_each = each.value.routing_policy == "LATENCY" ? [1] : []
    content { region = coalesce(each.value.region, "eu-central-1") }
  }

  # Alias (ALB/CloudFront) vs. Standard (A/CNAME/TXT)
  dynamic "alias" {
    for_each = each.value.alias != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }

  ttl     = each.value.alias == null ? each.value.ttl : null
  records = each.value.alias == null ? each.value.records : null
}


# Outputs


output "zone_id"      { value = local.zone_id }
output "zone_name"    { value = var.zone_name }
output "name_servers" {
  value       = var.create_zone ? aws_route53_zone.this[0].name_servers : null
  description = "Nameserver der Zone (nur wenn neu erstellt)."
}
