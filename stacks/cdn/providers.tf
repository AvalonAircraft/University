terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.54"
    }
  }
}

# Default-Provider (Region frei wählbar – für Auth & Route53)
provider "aws" {
  region = var.region
}

# Zusätzlich benötigter Provider in us-east-1 (ACM für CloudFront)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
