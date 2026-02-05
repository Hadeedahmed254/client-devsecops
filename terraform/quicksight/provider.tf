
provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "us-east-1"
}

terraform {
  backend "s3" {
    # This will be dynamically filled by the pipeline
  }
}
