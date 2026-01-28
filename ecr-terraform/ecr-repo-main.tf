provider "aws" {
  region = "us-east-1"  # Change as needed
}

resource "aws_ecr_repository" "bankapp" {
  name = "bankapp"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  force_delete = true

  tags = {
    Environment = "production"
    Project     = "bankapp"
  }
}
