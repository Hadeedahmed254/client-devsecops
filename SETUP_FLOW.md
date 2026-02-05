# 🔄 NEW SETUP FLOW - Visual Guide

## 📊 Complete Setup Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    ONE-TIME SETUP (Do Once)                      │
└─────────────────────────────────────────────────────────────────┘

STEP 1: SonarQube Setup
┌──────────────────────┐
│ Run sonarqube-setup  │
│ Terraform            │──→ SonarQube EC2 Created
└──────────────────────┘
           ↓
┌──────────────────────┐
│ Access SonarQube UI  │──→ Login (admin/admin)
└──────────────────────┘
           ↓
┌──────────────────────┐
│ Create Token         │──→ Copy token
└──────────────────────┘
           ↓
┌──────────────────────┐
│ Add to GitHub        │──→ SONAR_TOKEN (secret)
│ Secrets/Variables    │──→ SONAR_HOST_URL (variable)
└──────────────────────┘

═══════════════════════════════════════════════════════════════════

STEP 2: S3 Infrastructure Setup
┌──────────────────────┐
│ Run S3 Terraform     │──→ S3 Bucket Created
│ (new!)               │──→ IAM Role Created
└──────────────────────┘
           ↓
┌──────────────────────┐
│ Add to GitHub        │──→ AWS_REGION (variable)
│ Variables            │──→ AWS_ROLE_ARN (variable)
│                      │──→ S3_SECURITY_REPORTS_BUCKET (variable)
└──────────────────────┘

═══════════════════════════════════════════════════════════════════

STEP 3: Athena Database Setup
┌──────────────────────┐
│ Edit athena/setup.sql│──→ Replace {BUCKET_NAME}
└──────────────────────┘
           ↓
┌──────────────────────┐
│ Run in AWS Athena    │──→ Database & Tables Created
│ Console              │
└──────────────────────┘

═══════════════════════════════════════════════════════════════════
═══════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────┐
│                    EVERY TIME YOU RUN PIPELINE                   │
└─────────────────────────────────────────────────────────────────┘

STEP 4: Run CICD Pipeline
┌──────────────────────┐
│ Trigger CICD         │
│ Workflow             │
└──────────────────────┘
           ↓
┌──────────────────────┐
│ 1. Build & Test      │──→ Maven compile & test
└──────────────────────┘
           ↓
┌──────────────────────┐
│ 2. Security Scans    │──→ Trivy, Gitleaks, Snyk, SonarQube
└──────────────────────┘
           ↓
┌──────────────────────┐
│ 3. Upload to S3      │──→ s3://bucket/2026/02/05/run-001/
│ (new!)               │    ├── trivy-report.json
│                      │    ├── gitleaks-report.json
│                      │    ├── snyk-report.json
│                      │    ├── sonarqube-export.json
│                      │    └── metadata.json
└──────────────────────┘
           ↓
┌──────────────────────┐
│ 4. AI Analysis       │──→ Current scan analysis
│ (existing)           │
└──────────────────────┘
           ↓
┌──────────────────────┐
│ 5. AI Trend          │──→ Historical analysis
│ Intelligence (new!)  │──→ Risk score calculation
│                      │──→ Predictions
└──────────────────────┘

═══════════════════════════════════════════════════════════════════
═══════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────┐
│                    FOR CLIENT DEMO (Optional)                    │
└─────────────────────────────────────────────────────────────────┘

STEP 5: Generate Demo Data
┌──────────────────────┐
│ Run test data        │──→ Creates 30 days of fake data
│ generator            │
└──────────────────────┘
           ↓
┌──────────────────────┐
│ Repair Athena        │──→ MSCK REPAIR TABLE
│ Partitions           │
└──────────────────────┘
           ↓
┌──────────────────────┐
│ Setup QuickSight     │──→ Visual dashboards
└──────────────────────┘
           ↓
┌──────────────────────┐
│ Show Client:         │──→ S3 folder structure
│                      │──→ Athena queries
│                      │──→ QuickSight dashboard
│                      │──→ AI trend report
│                      │──→ GitHub issues
└──────────────────────┘
```

---

## 🎯 QUICK COMPARISON: Old vs New

### **OLD FLOW:**
```
1. Run sonarqube-setup.yml
2. Configure SonarQube token
3. Run cicd.yml
4. Reports go to GitHub Artifacts (90-day limit)
5. AI analyzes current scan only
```

### **NEW FLOW:**
```
1. Run sonarqube-setup.yml (same)
2. Configure SonarQube token (same)
3. Run S3 Terraform (NEW!)
4. Configure AWS variables (NEW!)
5. Setup Athena database (NEW!)
6. Run cicd.yml
7. Reports go to S3 (permanent) + GitHub Artifacts (backup)
8. AI analyzes current scan + historical trends (NEW!)
9. Weekly reports to Slack (NEW!)
10. Auto-create GitHub issues (NEW!)
```

---

## 📋 CHECKLIST FORMAT

### **First Time Setup:**
```
□ Deploy SonarQube
  └─ Run: cd sonarqube-terraform && terraform apply
  └─ Access SonarQube UI
  └─ Create token
  └─ Add SONAR_TOKEN to GitHub
  └─ Add SONAR_HOST_URL to GitHub

□ Deploy S3 Infrastructure
  └─ Run: cd terraform/security-reports-s3 && terraform apply
  └─ Add AWS_REGION to GitHub
  └─ Add AWS_ROLE_ARN to GitHub
  └─ Add S3_SECURITY_REPORTS_BUCKET to GitHub

□ Setup Athena
  └─ Edit athena/setup.sql (replace {BUCKET_NAME})
  └─ Run in AWS Athena console
  └─ Verify tables created

□ Verify All Secrets/Variables
  Secrets:
  └─ SNYK_TOKEN
  └─ SONAR_TOKEN
  └─ GEMINI_API_KEY
  
  Variables:
  └─ SONAR_HOST_URL
  └─ AWS_REGION
  └─ AWS_ROLE_ARN
  └─ S3_SECURITY_REPORTS_BUCKET
```

### **Every Pipeline Run:**
```
□ Trigger CICD Pipeline
□ Wait for completion
□ Verify S3 upload in logs
□ Check AI trend report in GitHub Actions summary
```

### **For Demo:**
```
□ Generate test data (30 days)
□ Repair Athena partitions
□ Setup QuickSight
□ Run pipeline once more
□ Show client all features
```

---

## 🚀 FASTEST PATH TO DEMO

**Time: 45 minutes**

```
1. Deploy SonarQube (10 min)
   └─ terraform apply + configure token

2. Deploy S3 (5 min)
   └─ terraform apply + configure GitHub

3. Setup Athena (3 min)
   └─ Run setup.sql

4. Generate demo data (5 min)
   └─ python scripts/generate_test_data.py

5. Repair partitions (1 min)
   └─ MSCK REPAIR TABLE

6. Run CICD pipeline (15 min)
   └─ Trigger workflow

7. Setup QuickSight (10 min)
   └─ Follow quick start guide

DONE! Ready to demo! 🎉
```

---

## 📞 NEED HELP?

**Read these in order:**
1. `COMPLETE_SETUP_GUIDE.md` (this file) - Step-by-step setup
2. `QUICK_REFERENCE.md` - Quick commands
3. `PREMIUM_COMPLETE.md` - Full feature guide
4. `docs/S3_SETUP.md` - Detailed S3 setup
5. `docs/QUICKSIGHT_QUICKSTART.md` - QuickSight setup

---

**🎯 Follow the flow above and you'll be demo-ready in 45 minutes!**
