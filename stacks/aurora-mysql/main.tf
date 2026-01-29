terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Optional: Monitoring Role per Name auflösen (wenn gesetzt)
data "aws_iam_role" "monitoring" {
  count = trim(var.monitoring_role_name) != "" ? 1 : 0
  name  = var.monitoring_role_name
}

locals {
  # Priorität: explizites ARN > per Name lookup > null
  monitoring_role_arn_resolved = (
    trim(var.monitoring_role_arn) != "" ? var.monitoring_role_arn :
    (length(data.aws_iam_role.monitoring) > 0 ? data.aws_iam_role.monitoring[0].arn : null)
  )

  # leer => null (nicht setzen)
  pi_kms_key_id_resolved = trim(var.pi_kms_key_id) != "" ? var.pi_kms_key_id : null

  # AZ leer => null
  writer_az_resolved = trim(var.writer_az) != "" ? var.writer_az : null
  reader_az_resolved = trim(var.reader_az) != "" ? var.reader_az : null
}

module "aurora" {
  source = "../../modules/aurora-mysql"

  name           = var.name
  engine_version = var.engine_version

  subnet_ids             = [var.subnet_private1_id, var.subnet_private2_id]
  vpc_security_group_ids = [var.sg_aurora_id]

  monitoring_role_arn = local.monitoring_role_arn_resolved
  pi_kms_key_id       = local.pi_kms_key_id_resolved

  deletion_protection   = var.deletion_protection
  backup_retention_days = var.backup_retention_days

  serverless_min_acu = var.serverless_min_acu
  serverless_max_acu = var.serverless_max_acu

  writer_az = local.writer_az_resolved
  reader_az = local.reader_az_resolved

  tags = var.tags
}
