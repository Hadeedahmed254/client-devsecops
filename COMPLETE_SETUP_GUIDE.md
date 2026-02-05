# 🚀 Complete Setup Guide - Step by Step

## Overview

This guide shows you the COMPLETE setup process from scratch, including SonarQube, S3, Athena, and the CI/CD pipeline.

---

## 📋 Prerequisites

- AWS Account with admin access
- GitHub repository
- Terraform installed
- AWS CLI configured

---

## 🎯 STEP-BY-STEP SETUP

### **PHASE 1: SonarQube Setup (First Time Only)**

#### Step 1.1: Deploy SonarQube Infrastructure
```bash
# Navigate to SonarQube Terraform
cd sonarqube-terraform

# Initialize and deploy
terraform init
terraform apply
```

**Outputs you'll get:**
- SonarQube URL (e.g., `http://ec2-xx-xx-xx-xx.compute-1.amazonaws.com:9000`)
- EC2 instance details

#### Step 1.2: Run SonarQube Setup Workflow
1. Go to GitHub Actions
2. Run workflow: **"SonarQube Setup"**
3. Wait for completion (~5 minutes)

#### Step 1.3: Access SonarQube
1. Open SonarQube URL from Terraform output
2. Default login:
   - Username: `admin`
   - Password: `admin`
3. Change password when prompted

#### Step 1.4: Create SonarQube Token
1. In SonarQube: User → My Account → Security
2. Generate Token:
   - Name: `github-actions`
   - Type: `Global Analysis Token`
   - Click "Generate"
3. **Copy the token** (you'll need it for GitHub)

#### Step 1.5: Create SonarQube Project
1. In SonarQube: Projects → Create Project
2. Project key: `GC-Bank`
3. Display name: `BankApp`
4. Click "Set Up"

#### Step 1.6: Configure GitHub Secrets/Variables
Go to GitHub: `Settings → Secrets and variables → Actions`

**Add Secret:**
- `SONAR_TOKEN`: (paste token from step 1.4)

**Add Variable:**
- `SONAR_HOST_URL`: (SonarQube URL from step 1.1)

---

### **PHASE 2: S3 Security Reports Setup (New!)**

#### Step 2.1: Deploy S3 Infrastructure
```bash
# Navigate to S3 Terraform
cd terraform/security-reports-s3

# Initialize and deploy
terraform init
terraform apply
```

**Outputs you'll get:**
- S3 bucket name (e.g., `bankapp-security-reports-123456789`)
- IAM role ARN (e.g., `arn:aws:iam::123456789:role/github-actions-security-reports-role`)
- Setup instructions

#### Step 2.2: Configure GitHub Variables for S3
Go to GitHub: `Settings → Secrets and variables → Actions → Variables`

**Add these variables:**
- `AWS_REGION`: `us-east-1`
- `AWS_ROLE_ARN`: (from Terraform output)
- `S3_SECURITY_REPORTS_BUCKET`: (from Terraform output)

---

### **PHASE 3: Athena Database Setup**

#### Step 3.1: Edit Athena Setup SQL
```bash
# Open the file
code athena/setup.sql

# Find and replace {BUCKET_NAME} with your actual bucket name
# Example: Replace {BUCKET_NAME} with bankapp-security-reports-123456789
```

#### Step 3.2: Run in AWS Athena Console
1. Go to AWS Console → Athena
2. Copy entire contents of `athena/setup.sql`
3. Paste and run in Athena query editor
4. Verify tables created:
   ```sql
   SHOW TABLES IN security_analytics;
   ```

You should see:
- `trivy_scans`
- `gitleaks_scans`
- `scan_metadata`

---

### **PHASE 4: Run CI/CD Pipeline**

#### Step 4.1: Verify All Secrets/Variables
Go to GitHub: `Settings → Secrets and variables → Actions`

**Secrets (should have):**
- ✅ `SNYK_TOKEN`
- ✅ `SONAR_TOKEN`
- ✅ `GEMINI_API_KEY`

**Variables (should have):**
- ✅ `SONAR_HOST_URL`
- ✅ `AWS_REGION`
- ✅ `AWS_ROLE_ARN`
- ✅ `S3_SECURITY_REPORTS_BUCKET`

#### Step 4.2: Run CICD Pipeline
1. Go to GitHub Actions
2. Select workflow: **"CICD Pipeline"**
3. Click "Run workflow"
4. Wait for completion (~10-15 minutes)

#### Step 4.3: Verify S3 Upload
Check workflow logs for:
```
✅ Security reports uploaded to: s3://bucket-name/2026/02/05/run-001/
```

Verify in AWS:
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

---

### **PHASE 5: Generate Demo Data (Optional - For Client Demo)**

#### Step 5.1: Run Test Data Generator
```bash
# Set environment variable
export S3_SECURITY_REPORTS_BUCKET=your-bucket-name

# Run generator (creates 30 days of data)
python scripts/generate_test_data.py
```

#### Step 5.2: Repair Athena Partitions
```sql
-- Run in AWS Athena console
MSCK REPAIR TABLE security_analytics.trivy_scans;
MSCK REPAIR TABLE security_analytics.gitleaks_scans;
MSCK REPAIR TABLE security_analytics.scan_metadata;
```

#### Step 5.3: Verify Data in Athena
```sql
-- Check data exists
SELECT COUNT(*) FROM security_analytics.trivy_scans;

-- Should return 30+ if test data was generated
```

---

### **PHASE 6: Setup QuickSight (Optional)**

Follow: `docs/QUICKSIGHT_QUICKSTART.md`

**Quick Steps:**
1. Enable QuickSight in AWS Console
2. Connect to Athena data source
3. Create dataset from `security_analytics` database
4. Build visualizations (line chart, pie chart, KPI)
5. Publish dashboard

**Time:** ~10 minutes

---

### **PHASE 7: Setup Weekly Reports (Optional)**

#### Step 7.1: Create Slack Webhook (Optional)
1. Go to https://api.slack.com/apps
2. Create new app → Incoming Webhooks
3. Add webhook to workspace
4. Copy webhook URL

#### Step 7.2: Add Slack Webhook to GitHub
Go to GitHub: `Settings → Secrets and variables → Actions → Secrets`

**Add Secret:**
- `SLACK_WEBHOOK_URL`: (your webhook URL)

#### Step 7.3: Test Weekly Report
1. Go to GitHub Actions
2. Run workflow: **"Weekly Security Report"**
3. Check Slack for message
4. Check GitHub Issues for auto-created issues

---

## 🎯 COMPLETE SETUP CHECKLIST

### **One-Time Setup:**
- [ ] Deploy SonarQube (Phase 1)
- [ ] Configure SonarQube token
- [ ] Deploy S3 infrastructure (Phase 2)
- [ ] Setup Athena database (Phase 3)
- [ ] Configure all GitHub secrets/variables

### **Every Time You Want to Demo:**
- [ ] Run CICD Pipeline (Phase 4)
- [ ] Verify S3 upload
- [ ] (Optional) Generate test data (Phase 5)
- [ ] (Optional) Setup QuickSight (Phase 6)

### **Optional Automation:**
- [ ] Setup Slack webhook (Phase 7)
- [ ] Test weekly reports

---

## 📊 WHAT RUNS WHEN

### **Workflow: CICD Pipeline** (Manual Trigger)
**What it does:**
1. Build and test code
2. Run security scans (Trivy, Gitleaks, Snyk, SonarQube)
3. Upload reports to S3
4. Run AI security analysis (current scan)
5. Run AI trend intelligence (historical analysis)
6. Upload artifacts to GitHub

**When to run:** Every time you want to scan code

---

### **Workflow: Weekly Security Report** (Scheduled: Every Monday 9 AM)
**What it does:**
1. Run AI trend intelligence
2. Send Slack summary
3. Create GitHub issues for critical vulnerabilities

**When to run:** Automatically every Monday, or manually for testing

---

## 🔄 TYPICAL WORKFLOW

### **First Time Setup (Do Once):**
```
1. Deploy SonarQube → Configure token
2. Deploy S3 → Configure GitHub variables
3. Setup Athena → Run setup.sql
4. Run CICD Pipeline → Verify everything works
```

### **For Client Demo:**
```
1. Generate test data (30 days)
2. Repair Athena partitions
3. Setup QuickSight
4. Run CICD Pipeline once more
5. Show:
   - S3 folder structure
   - Athena queries
   - QuickSight dashboard
   - AI trend report
   - GitHub issues
```

### **Production Use:**
```
1. Run CICD Pipeline on every commit (or manually)
2. Weekly report runs automatically
3. Review Slack messages
4. Fix issues created in GitHub
5. Track trends in QuickSight
```

---

## 🆘 TROUBLESHOOTING

### **Issue: S3 upload fails**
**Solution:**
- Verify `AWS_ROLE_ARN` is correct
- Verify `S3_SECURITY_REPORTS_BUCKET` is correct
- Check IAM role trust policy includes your GitHub repo

### **Issue: Athena returns no data**
**Solution:**
```sql
-- Repair partitions
MSCK REPAIR TABLE security_analytics.trivy_scans;

-- Verify data exists
SELECT * FROM security_analytics.trivy_scans LIMIT 10;
```

### **Issue: SonarQube scan fails**
**Solution:**
- Verify `SONAR_TOKEN` is valid
- Verify `SONAR_HOST_URL` is accessible
- Check SonarQube project key is `GC-Bank`

### **Issue: AI trend intelligence fails**
**Solution:**
- Verify `GEMINI_API_KEY` is set
- Verify Athena has data (run pipeline at least once)
- Check AWS credentials are configured

---

## 📞 QUICK REFERENCE

**Documentation:**
- Complete guide: `PREMIUM_COMPLETE.md`
- Quick start: `QUICK_REFERENCE.md`
- S3 setup: `docs/S3_SETUP.md`
- QuickSight: `docs/QUICKSIGHT_QUICKSTART.md`

**Commands:**
```bash
# Deploy SonarQube
cd sonarqube-terraform && terraform apply

# Deploy S3
cd terraform/security-reports-s3 && terraform apply

# Generate test data
python scripts/generate_test_data.py

# Check S3
aws s3 ls s3://YOUR-BUCKET/2026/02/05/ --recursive
```

---

## ✅ SUCCESS CRITERIA

After setup, you should have:
- ✅ SonarQube running and accessible
- ✅ S3 bucket created with reports
- ✅ Athena database with tables
- ✅ CICD pipeline running successfully
- ✅ AI reports generated
- ✅ (Optional) QuickSight dashboard
- ✅ (Optional) Slack notifications

---

**🎉 You're ready to demo!**
