############################
# Data
############################
data "aws_partition" "current" {}

############################
# Inputs
############################
variable "role_name" { type = string }                    # bewusst ohne Default
variable "role_path" { type = string, default = "/" }
variable "tags"      { type = map(string), default = {} }

# Optional: weitere Managed Policies anhängen (z. B. CloudWatch-Agent o. ä.)
variable "extra_policy_arns" {
  type    = list(string)
  default = []
}

# Guards
variable "role_name" {
  type = string

  validation {
    condition     = length(trim(var.role_name)) > 0
    error_message = "role_name darf nicht leer sein."
  }
}

############################
# Trust Policy (ECS Tasks)
############################
data "aws_iam_policy_document" "assume_ecs_tasks" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["ecs-tasks.amazonaws.com"] }
    actions   = ["sts:AssumeRole"]
  }
}

############################
# Role
############################
resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
  tags               = var.tags
}

############################
# Attach AWS-managed Execution Policy (pull ECR, push logs, secrets, etc.)
############################
resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

############################
# Optional extra managed policies
############################
resource "aws_iam_role_policy_attachment" "extra" {
  for_each   = toset(var.extra_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

############################
# Outputs
############################
output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn }
