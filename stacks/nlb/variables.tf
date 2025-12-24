variable "region" { type = string, default = "us-east-1" }

# Aus dem Network-Stack (module.vpc.* Outputs übernehmen)
variable "vpc_id"          { type = string }
variable "subnet_private1" { type = string }  # z.B. module.vpc.subnet_private1_id
variable "subnet_private2" { type = string }  # z.B. module.vpc.subnet_private2_id

# Aus dem SG-Stack (module.sg.sg_nlb_fargate_privatelink_id)
variable "nlb_sg_id" { type = string }

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    Type            = "NLB"
    TenantID = ""
  }
}
