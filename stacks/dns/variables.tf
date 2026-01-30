variable "create_zone" {
  type        = bool
  description = "Wenn true, wird eine neue public Hosted Zone erstellt."
  default     = true
}

variable "zone_name" {
  type        = string
  description = "Domain der Hosted Zone (z.B. example.com). Muss dir gehören."
}

variable "dns_records" {
  description = "DNS Records, die in der Zone erstellt werden sollen. Default leer, da account-/domain-spezifisch."
  type = list(object({
    name    = string
    type    = string
    records = optional(list(string), [])

    ttl = optional(number)

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
  default = []
}
