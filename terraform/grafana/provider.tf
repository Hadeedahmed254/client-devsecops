
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    # Dynamically filled by pipeline
  }
}

provider "aws" {
  region = var.aws_region
}
