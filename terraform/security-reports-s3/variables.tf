variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_prefix" {
  description = "Prefix for S3 bucket name"
  type        = string
  default     = "bankapp-security-reports"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "retention_days" {
  description = "Number of days to retain reports before deletion"
  type        = number
  default     = 90
}

variable "glacier_transition_days" {
  description = "Number of days before transitioning to Glacier storage"
  type        = number
  default     = 30
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
  default     = "Hadeedahmed254/githubaction-AI"
}

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
  default     = ""
}
