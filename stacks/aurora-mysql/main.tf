module "aurora" {
  source = "../../modules/aurora-mysql"

  name           = var.name
  engine_version = var.engine_version

  subnet_ids             = [var.subnet_private1_id, var.subnet_private2_id]
  vpc_security_group_ids = [var.sg_aurora_id]

  monitoring_role_arn = var.monitoring_role_arn
  pi_kms_key_id       = var.pi_kms_key_id

  deletion_protection   = var.deletion_protection
  backup_retention_days = var.backup_retention_days

  serverless_min_acu = var.serverless_min_acu
  serverless_max_acu = var.serverless_max_acu

  writer_az = var.writer_az
  reader_az = var.reader_az

  tags = var.tags
}

output "cluster_arn"          { value = module.aurora.cluster_arn }
output "cluster_id"           { value = module.aurora.cluster_id }
output "cluster_resource_id"  { value = module.aurora.cluster_resource_id }
output "endpoint_writer"      { value = module.aurora.endpoint_writer }
output "endpoint_reader"      { value = module.aurora.endpoint_reader }
output "db_subnet_group"      { value = module.aurora.db_subnet_group }
output "instance_writer_id"   { value = module.aurora.instance_writer_id }
output "instance_reader_id"   { value = module.aurora.instance_reader_id }
