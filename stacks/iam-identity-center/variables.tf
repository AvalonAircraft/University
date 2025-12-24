variable "region"     { type = string, default = "us-east-1" }
variable "account_id" { type = string, default = "186261963982" }

# adminUser (Kristian Stockhaus)
variable "admin_user_username"     { type = string, default = "adminUser" }
variable "admin_user_email"        { type = string, default = "stockhaus.kristian@gmail.com" }
variable "admin_user_given_name"   { type = string, default = "Kristian" }
variable "admin_user_family_name"  { type = string, default = "Stockhaus" }
variable "admin_user_display_name" { type = string, default = "Kristian Stockhaus" }

# ECRPushMinimal (Kristoffer Stockhaus)
variable "ecr_user_username"     { type = string, default = "ECRPushMinimal" }
variable "ecr_user_email"        { type = string, default = "kl.stockhaus@gmail.com" }
variable "ecr_user_given_name"   { type = string, default = "Kristoffer" }
variable "ecr_user_family_name"  { type = string, default = "Stockhaus" }
variable "ecr_user_display_name" { type = string, default = "Kristoffer Stockhaus" }

variable "group_admin_name" { type = string, default = "AdminGroup" }
variable "group_devs_name"  { type = string, default = "Developers" }
