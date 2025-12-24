############################
# Inputs
############################
variable "cluster_name"   { type = string }
variable "service_name"   { type = string }

# Task Definition
variable "task_family"    { type = string, default = "" }   # z.B. "fargate-agent-task"
variable "cpu"            { type = number }                 # 256, 512, 1024, 2048, 4096, 8192 (Fargate-Valid)
variable "memory"         { type = number }                 # 512..30720 (abhängig von CPU)
variable "container_name" { type = string }
variable "container_image"{ type = string }
variable "container_port" { type = number, default = 8080 }

# Env (Container)
variable "container_environment" {
  type    = map(string)
  default = {}
}

# Networking
variable "subnet_ids"        { type = list(string) }  # private Subnets empfohlen
variable "security_group_id" { type = string }        # z.B. sg-xxxx (ecs-fargate)
variable "assign_public_ip"  { type = bool, default = false }

# Load Balancer
variable "target_group_arn" { type = string }         # ARN der NLB Target Group (TCP:port)

# CloudWatch Logs
variable "log_group_name"     { type = string, default = "/ecs/service" }
variable "log_retention_days" { type = number, default = 14 }

# Optional: vorhandene Rollen wiederverwenden
variable "task_role_arn"      { type = string, default = "" }
variable "execution_role_arn" { type = string, default = "" }

variable "tags" { type = map(string), default = {} }

############################
# Environment
############################
data "aws_region"           "current" {}
data "aws_caller_identity"  "current" {}
data "aws_partition"        "current" {}

locals {
  # Wenn keine ARNs übergeben werden, nutzen wir die erzeugten Rollen (Index 0)
  effective_task_role_arn      = var.task_role_arn      != "" ? var.task_role_arn      : aws_iam_role.task[0].arn
  effective_execution_role_arn = var.execution_role_arn != "" ? var.execution_role_arn : aws_iam_role.execution[0].arn

  # Container-Definition als JSON
  container_def = [{
    name       = var.container_name
    image      = var.container_image
    essential  = true

    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]

    environment = [for k, v in var.container_environment : {
      name  = k
      value = v
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.log_group_name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "ecs"
        awslogs-create-group  = "false"
      }
    }
  }]
}

############################
# CloudWatch Logs
############################
resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

############################
# ECS Cluster
############################
resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
  tags = var.tags
}

############################
# IAM (optional erzeugen)
############################
# Task Role (App-Rechte)
data "aws_iam_policy_document" "task_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "task" {
  count              = var.task_role_arn == "" ? 1 : 0
  name               = "${var.service_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

# Execution Role (Pull from ECR, Push Logs, Get Secrets etc.)
resource "aws_iam_role" "execution" {
  count              = var.execution_role_arn == "" ? 1 : 0
  name               = "${var.service_name}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

# Managed Policy für Execution Role
resource "aws_iam_role_policy_attachment" "execution_managed" {
  count      = var.execution_role_arn == "" ? 1 : 0
  role       = aws_iam_role.execution[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

############################
# Task Definition (Fargate)
############################
resource "aws_ecs_task_definition" "this" {
  family                   = var.task_family != "" ? var.task_family : "${var.service_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = tostring(var.cpu)
  memory = tostring(var.memory)

  execution_role_arn = local.effective_execution_role_arn
  task_role_arn      = local.effective_task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode(local.container_def)

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy_attachment.execution_managed
  ]
}

############################
# Service (Fargate + NLB TargetGroup)
############################
resource "aws_ecs_service" "this" {
  name             = var.service_name
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.this.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  propagate_tags = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = var.tags

  depends_on = [aws_ecs_task_definition.this]
}

############################
# Outputs
############################
output "cluster_arn"         { value = aws_ecs_cluster.this.arn }
output "service_arn"         { value = aws_ecs_service.this.arn }
output "task_definition_arn" { value = aws_ecs_task_definition.this.arn }
output "task_family"         { value = aws_ecs_task_definition.this.family }
