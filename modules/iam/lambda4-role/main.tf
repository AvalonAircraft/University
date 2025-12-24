############################
# Inputs
############################
variable "role_name"   { type = string }
variable "role_path"   { type = string,  default = "/service-role/" }
variable "policy_arns" { type = list(string), default = [] }
variable "tags"        { type = map(string),   default = {} }

# Guard, damit ich keine leeren Namen übergebe
variable "role_name" {
  type = string

  validation {
    condition     = length(var.role_name) > 0
    error_message = "role_name darf nicht leer sein."
  }
}


############################
# Trust policy (Lambda)
############################
data "aws_iam_policy_document" "trust_lambda" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

############################
# IAM Role
############################
resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust_lambda.json
  tags               = var.tags
}

############################
# Attach managed policies
############################
resource "aws_iam_role_policy_attachment" "attached" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

############################
# Outputs
############################
output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn  }
