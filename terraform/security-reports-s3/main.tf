terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# S3 bucket for security reports
resource "aws_s3_bucket" "security_reports" {
  bucket = "${var.bucket_prefix}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Security Reports Storage"
    Project     = "BankApp"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "CI/CD Security Scan Reports"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "security_reports" {
  bucket = aws_s3_bucket.security_reports.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "security_reports" {
  bucket = aws_s3_bucket.security_reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "security_reports" {
  bucket = aws_s3_bucket.security_reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "security_reports" {
  bucket = aws_s3_bucket.security_reports.id

  rule {
    id     = "archive-old-reports"
    status = "Enabled"

    # Transition to Glacier after 30 days
    transition {
      days          = var.glacier_transition_days
      storage_class = "GLACIER"
    }

    # Delete after retention period
    expiration {
      days = var.retention_days
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# S3 bucket policy
resource "aws_s3_bucket_policy" "security_reports" {
  bucket = aws_s3_bucket.security_reports.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnforcedTLS"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.security_reports.arn,
          "${aws_s3_bucket.security_reports.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
