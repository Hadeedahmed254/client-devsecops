# Terraform Backend Configuration
# 
# Uncomment and configure this if you want to store Terraform state in S3
# This is recommended for team collaboration
#
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "security-reports-s3/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

# For now, using local backend (terraform.tfstate will be created locally)
# This is fine for single-user setup
