variable "region" {
  type    = string
  default = "us-east-1"
}


# Required inputs (aus Network/VPC + SG)

variable "vpc_id" {
  type = string
}

variable "subnet_private1" {
  type        = string
  description = "Private subnet ID 1 (z.B. aus network output subnet_private1_id)"
}

variable "subnet_private2" {
  type        = string
  description = "Private subnet ID 2 (z.B. aus network output subnet_private2_id)"
}

variable "nlb_sg_id" {
  type        = string
  description = "Security group id for the NLB (z.B. sg_nlb_fargate_privatelink_id)"
}


# NLB settings (defaults = professor-safe)

variable "name" {
  type        = string
  description = "Name of the NLB"
  default     = "nlb-fargate"
}

variable "internal" {
  type        = bool
  description = "Internal NLB (true) vs internet-facing (false)"
  default     = true
}

variable "ip_address_type" {
  type        = string
  description = "ipv4 or dualstack"
  default     = "ipv4"
  validation {
    condition     = contains(["ipv4", "dualstack"], var.ip_address_type)
    error_message = "ip_address_type must be 'ipv4' or 'dualstack'."
  }
}


# Target Group / Listener

variable "service_port" {
  type        = number
  description = "Port for TG + Listener"
  default     = 8080
}

variable "tg_name" {
  type        = string
  description = "Target group name"
  default     = "fargate-nlb-targets"
}

variable "tg_protocol" {
  type        = string
  description = "Target group protocol (TCP/UDP/TLS)"
  default     = "TCP"
}

variable "listener_protocol" {
  type        = string
  description = "Listener protocol (TCP/UDP/TLS)"
  default     = "TCP"
}

############################
# Health Check
############################
variable "hc_enabled" {
  type        = bool
  description = "Enable health checks"
  default     = true
}

variable "hc_protocol" {
  type        = string
  description = "Health check protocol (TCP/HTTP/HTTPS)"
  default     = "TCP"
}

variable "hc_port" {
  type        = string
  description = "Health check port: 'traffic-port' or explicit port number as string"
  default     = "traffic-port"
}

variable "hc_interval" {
  type        = number
  description = "Health check interval in seconds"
  default     = 10
}

variable "hc_healthy_thr" {
  type        = number
  description = "Healthy threshold"
  default     = 3
}

variable "hc_unhealthy_thr" {
  type        = number
  description = "Unhealthy threshold"
  default     = 3
}


# Optional hardening/perf

variable "enable_cross_zone" {
  type        = bool
  description = "Enable cross-zone load balancing"
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "Prevent accidental deletion"
  default     = false
}


# Tags

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    Type            = "NLB"
    TenantID        = ""
  }
}
