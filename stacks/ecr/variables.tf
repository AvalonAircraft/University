data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

variable "region"          { type = string, default = "us-east-1" }

# Repo-Details aus meiner Konsole
variable "repository_name" { type = string, default = "tenant1/hr-agent" }

# KMS (MRK aus meiner Konsole)
variable "kms_key_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/mrk-fe405a6602914696b9b77186794bfb39"
}

# In deiner Konsole: Scanfrequenz = "Manuell" => scan_on_push = false
variable "scan_on_push"         { type = bool,   default = false }
variable "image_tag_mutability" { type = string, default = "IMMUTABLE" } # "Unveränderlich"

# Optional: Lifecycle-Policy (leer lassen, wenn nicht gewünscht)
# Beispiel-Policy (als JSON einsetzen), um z.B. ungetaggte Images nach 7 Tagen zu löschen:
# {
#   "rules": [{
#     "rulePriority": 1,
#     "description": "Expire untagged after 7 days",
#     "selection": { "tagStatus": "untagged", "countType": "sinceImagePushed", "countUnit": "days", "countNumber": 7 },
#     "action": { "type": "expire" }
#   }]
# }
variable "lifecycle_policy_json" { type = string, default = "" }

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    Type            = "ECR"
    TenantID = ""
  }
}
