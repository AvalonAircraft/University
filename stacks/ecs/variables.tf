data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

variable "region"      { type = string, default = "us-east-1" }

# Cluster/Service
variable "cluster_name" { type = string, default = "ai_agent_fargate_container" }
variable "service_name" { type = string, default = "email-agent-svc" }
variable "task_family"  { type = string, default = "fargate-agent-task" }

# Container
variable "container_name"  { type = string, default = "hr-agent" }
variable "container_image" {
  type        = string
  description = "Container image URI (public DockerHub/public.ecr.aws or private ECR)."
  default     = "public.ecr.aws/nginx/nginx:latest"

  validation {
    condition     = length(trim(var.container_image)) > 0
    error_message = "container_image must be a non-empty string."
  }
}
variable "container_port"  { type = number, default = 8080 }

# Fargate Sizing
variable "cpu"    { type = number, default = 1024 }  # ~1 vCPU
variable "memory" { type = number, default = 2048 }  # 2 GB

# Networking
variable "subnet_ids"        { type = list(string) }                    # IDs aus Network-Stack übergeben
variable "security_group_id" {
  type        = string
  description = "ECS service security group id"
}variable "assign_public_ip"  { type = bool, default = false }

# Load Balancer Target Group
variable "target_group_arn" {
  type        = string
  description = "Target group ARN for the service"
}

# Logs
variable "log_group_name"     { type = string, default = "/ecs/fargate-agent-task" }
variable "log_retention_days" { type = number, default = 14 }

# Optional vorhandene Rollen (leer lassen, wenn Modul sie erstellen soll)
variable "task_role_arn" {
  type        = string
  description = "Optional: existing task role ARN. Leave empty to let module create it."
  default     = ""
}

variable "execution_role_arn" {
  type        = string
  description = "Optional: existing execution role ARN. Leave empty to let module create it."
  default     = ""
}

variable "task_role_name" {
  type        = string
  description = "Optional: existing task role NAME to look up. Leave empty to skip lookup."
  default     = ""
}

variable "execution_role_name" {
  type        = string
  description = "Optional: existing execution role NAME to look up. Leave empty to skip lookup."
  default     = ""
}


# Env ins Container
variable "container_environment" {
  type = map(string)
  default = {
    AWS_REGION          = "us-east-1"

    # Bedrock Konfiguration bleibt drin
    BEDROCK_MODEL_ID    = "anthropic.claude-3-haiku-20240307-v1:0"
    DEFAULT_LANG        = "de"

    # Integration-Flags default OFF, damit "deploy works" ohne Abhängigkeiten
    USE_BEDROCK         = "0"
    USE_COMPREHEND      = "0"
    SEND_TO_EVENTBRIDGE = "0"

    # Optional: EventBridge defaults leer/neutral, damit nix hard-failt
    EVENT_BUS_NAME      = ""
    EVENT_DETAIL_TYPE   = ""
    EVENT_SOURCE        = ""
  }
}


variable "tags" {
  type = map(string)
  default = {
    Projekt   = "MiraeDrive"
    Umgebung  = "Produktiv"
    Component = "ECS"
    TenantID = ""
  }
}
