# Premium S3 Security Reports Setup Guide

## Overview

This setup enables enterprise-grade security report storage in S3 with trend analysis capabilities using AWS Athena and QuickSight.

## Prerequisites

- AWS Account with admin access
- Terraform installed (>= 1.0)
- AWS CLI configured
- GitHub repository with Actions enabled

## Step 1: Deploy Infrastructure

### 1.1 Navigate to Terraform directory
```bash
cd terraform/security-reports-s3
```

### 1.2 Initialize Terraform
```bash
terraform init
```

### 1.3 Review and apply
```bash
terraform plan
terraform apply
```

### 1.4 Save outputs
```bash
terraform output
```

You'll see:
- `s3_bucket_name`: Your S3 bucket name
- `github_actions_role_arn`: IAM role ARN for GitHub Actions
- `aws_region`: AWS region

## Step 2: Configure GitHub

### 2.1 Add GitHub Variables

Go to: `Settings → Secrets and variables → Actions → Variables`

Add these variables:
- `AWS_REGION`: `us-east-1` (or your region)
- `AWS_ROLE_ARN`: (from Terraform output)
- `S3_SECURITY_REPORTS_BUCKET`: (from Terraform output)

### 2.2 Existing Secrets (should already exist)
- `SNYK_TOKEN`
- `SONAR_TOKEN`
- `GEMINI_API_KEY`

## Step 3: Set Up Athena Database

### 3.1 Replace bucket name in setup.sql
```bash
# Edit athena/setup.sql
# Replace {BUCKET_NAME} with your actual bucket name from Terraform output
```

### 3.2 Run in AWS Athena Console
1. Go to AWS Athena console
2. Copy contents of `athena/setup.sql`
3. Replace `{BUCKET_NAME}` with your bucket name
4. Run the SQL

### 3.3 Verify tables created
```sql
SHOW TABLES IN security_analytics;
```

You should see:
- `trivy_scans`
- `gitleaks_scans`
- `scan_metadata`

## Step 4: Test the Pipeline

### 4.1 Trigger workflow
Go to GitHub Actions and manually trigger "CICD Pipeline"

### 4.2 Verify S3 upload
Check the workflow logs for:
```
✅ Security reports uploaded to: s3://bucket-name/2026/02/05/run-XXX/
```

### 4.3 Verify in S3
```bash
aws s3 ls s3://YOUR-BUCKET-NAME/2026/02/05/ --recursive
```

You should see:
```
2026/02/05/run-001/trivy-report.json
2026/02/05/run-001/snyk-report.json
2026/02/05/run-001/gitleaks-report.json
2026/02/05/run-001/sonarqube-export.json
2026/02/05/run-001/metadata.json
```

## Step 5: Test Athena Queries

### 5.1 Run sample query
```sql
SELECT COUNT(*) FROM security_analytics.trivy_scans;
```

### 5.2 Run vulnerability trends query
Copy and run: `athena/queries/vulnerability-trends.sql`

### 5.3 Run risk score query
Copy and run: `athena/queries/risk-score.sql`

## Step 6: Set Up QuickSight (Optional)

### 6.1 Enable QuickSight
1. Go to AWS QuickSight console
2. Sign up if not already enabled
3. Choose Standard edition

### 6.2 Connect to Athena
1. Create new dataset
2. Choose Athena as data source
3. Select `security_analytics` database
4. Choose tables to visualize

### 6.3 Create visualizations
- Line chart: Vulnerability trends over time
- Bar chart: Severity breakdown
- KPI: Current risk score
- Table: Critical vulnerabilities

## Troubleshooting

### Issue: S3 upload fails
**Solution:** Check GitHub variables are set correctly
```bash
# Verify in GitHub: Settings → Secrets and variables → Actions
AWS_REGION
AWS_ROLE_ARN
S3_SECURITY_REPORTS_BUCKET
```

### Issue: Athena query returns no data
**Solution:** Repair partitions
```sql
MSCK REPAIR TABLE security_analytics.trivy_scans;
MSCK REPAIR TABLE security_analytics.gitleaks_scans;
```

### Issue: IAM permission denied
**Solution:** Verify IAM role trust policy includes your GitHub repo
```bash
terraform output github_actions_role_arn
# Check in AWS IAM console that trust policy includes:
# repo:Hadeedahmed254/githubaction-AI:*
```

## Next Steps

1. Run pipeline 5-10 times to generate historical data
2. Set up QuickSight dashboards
3. Configure AI trend intelligence scripts
4. Set up weekly Slack reports (optional)
5. Configure auto GitHub issue creation (optional)

## Cost Estimate

**Monthly AWS Costs:**
- S3 storage: ~$0.20 (with lifecycle policies)
- Athena queries: ~$0.10 (pay per query)
- QuickSight: $9/month (Standard edition, first user)
- **Total: ~$10/month**

## Support

For issues or questions, refer to:
- `docs/TROUBLESHOOTING.md`
- `docs/ARCHITECTURE.md`
- GitHub Issues

## Clean Up

To remove all resources:
```bash
cd terraform/security-reports-s3
terraform destroy
```

**Warning:** This will delete the S3 bucket and all reports!
