output "s3_bucket_name" {
  description = "Name of the S3 bucket for security reports"
  value       = aws_s3_bucket.security_reports.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.security_reports.arn
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "aws_region" {
  description = "AWS region where resources are created"
  value       = var.aws_region
}

output "setup_instructions" {
  description = "Next steps to configure GitHub"
  value       = <<-EOT
    
    ========================================
    S3 Security Reports Setup Complete!
    ========================================
    
    Add these to your GitHub repository secrets/variables:
    
    Variables (Settings → Secrets and variables → Actions → Variables):
    - AWS_REGION: ${var.aws_region}
    - AWS_ROLE_ARN: ${aws_iam_role.github_actions.arn}
    - S3_SECURITY_REPORTS_BUCKET: ${aws_s3_bucket.security_reports.id}
    
    Next steps:
    1. Update .github/workflows/cicd.yml with S3 upload steps
    2. Set up Athena database (run athena/setup.sql)
    3. Configure QuickSight dashboards
    4. Test the pipeline
    
    S3 Bucket: ${aws_s3_bucket.security_reports.id}
    IAM Role: ${aws_iam_role.github_actions.arn}
    
    ========================================
  EOT
}
