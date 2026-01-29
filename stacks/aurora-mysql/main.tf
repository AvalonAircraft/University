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

locals {
  # Optional: wenn leer => null (Terraform übergibt dann "nicht gesetzt")
  monitoring_role_arn = trim(var.monitoring_role_arn) != "" ? var.monitoring_role_arn : null
  pi_kms_key_id       = trim(var.pi_kms_key_id) != "" ? var.pi_kms_key_id : null
}

module "aurora" {
  source = "../../modules/aurora-mysql"

  name           = var.name
  engine_version = var.engine_version

  # Robust: Listen statt einzelne Variablen
  subnet_ids             = var.subnet_ids
  vpc_security_group_ids = var.security_group_ids

  # Optional (professor-sicher)
  monitoring_role_arn = local.monitoring_role_arn
  pi_kms_key_id       = local.pi_kms_key_id

  deletion_protection   = var.deletion_protection
  backup_retention_days = var.backup_retention_days

  serverless_min_acu = var.serverless_min_acu
  serverless_max_acu = var.serverless_max_acu

  writer_az = var.writer_az
  reader_az = var.reader_az

  tags = var.tags
}
