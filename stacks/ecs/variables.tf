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
variable "container_image" { type = string, default = "111111111111.dkr.ecr.us-east-1.amazonaws.com/tenant1/hr-agent:latest" }
variable "container_port"  { type = number, default = 8080 }

# Fargate Sizing
variable "cpu"    { type = number, default = 1024 }  # ~1 vCPU
variable "memory" { type = number, default = 2048 }  # 2 GB

# Networking
variable "subnet_ids"        { type = list(string) }                    # IDs aus Network-Stack übergeben
variable "security_group_id" { type = string, default = "sg-08eacce4ac5d0f575" } # ecs-fargate
variable "assign_public_ip"  { type = bool, default = false }

# Load Balancer Target Group
variable "target_group_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:elasticloadbalancing:${data.aws_region.current.name}:111111111111:targetgroup/fargate-nlb-targets/0123456789abcdef"
}

# Logs
variable "log_group_name"     { type = string, default = "/ecs/fargate-agent-task" }
variable "log_retention_days" { type = number, default = 14 }

# Optional vorhandene Rollen (leer lassen, wenn Modul sie erstellen soll)
variable "task_role_arn"      { type = string, default = "" }
variable "execution_role_arn" { type = string, default = "" }

# Env ins Container
variable "container_environment" {
  type = map(string)
  default = {
    AWS_REGION          = "us-east-1"
    BEDROCK_MODEL_ID    = "anthropic.claude-3-haiku-20240307-v1:0"
    DEFAULT_LANG        = "de"
    EVENT_BUS_NAME      = "event-bus-miraedrive-2"
    EVENT_DETAIL_TYPE   = "EmailAnalyzed"
    EVENT_SOURCE        = "app.email-agent"
    SEND_TO_EVENTBRIDGE = "1"
    USE_BEDROCK         = "1"
    USE_COMPREHEND      = "0"
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
