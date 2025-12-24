# Vor dem module-Block einfügen: vorhandene IAM-Rollen per Name auflösen
data "aws_iam_role" "task" {
  name = "agentTaskRole"                 # vorhandene Task-Role (falls vorhanden)
}

data "aws_iam_role" "execution" {
  name = "ecsTaskExecutionRole-ai-agent" # vorhandene Execution-Role (falls vorhanden)
}

module "ecs" {
  source = "../../modules/ecs"

  cluster_name = var.cluster_name
  service_name = var.service_name
  task_family  = var.task_family

  container_name  = var.container_name
  container_image = var.container_image
  container_port  = var.container_port

  cpu    = var.cpu
  memory = var.memory

  subnet_ids        = var.subnet_ids
  security_group_id = var.security_group_id
  assign_public_ip  = var.assign_public_ip

  target_group_arn = var.target_group_arn

  log_group_name     = var.log_group_name
  log_retention_days = var.log_retention_days

  # vorhandene Rollen nutzen (wenn die Data-Sources nicht existieren, einfach Variablen leer lassen)
  task_role_arn      = data.aws_iam_role.task.arn
  execution_role_arn = data.aws_iam_role.execution.arn

  container_environment = var.container_environment
  tags = var.tags
}

output "ecs_cluster_arn"         { value = module.ecs.cluster_arn }
output "ecs_service_arn"         { value = module.ecs.service_arn }
output "ecs_task_definition_arn" { value = module.ecs.task_definition_arn }
output "ecs_task_family"         { value = module.ecs.task_family }
