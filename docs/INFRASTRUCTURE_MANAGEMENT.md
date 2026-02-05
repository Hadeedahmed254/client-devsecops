# 🚀 Infrastructure Management - Automated Deploy & Destroy

## Overview

This guide shows you how to **deploy and destroy** the entire S3 infrastructure using GitHub Actions, with automatic state management.

---

## 🎯 What This Workflow Does

### **Deploy Action:**
1. ✅ Creates Terraform state bucket automatically
2. ✅ Deploys S3 security reports infrastructure
3. ✅ Creates IAM roles with OIDC
4. ✅ Outputs variables for GitHub configuration
5. ✅ Stores state in S3 for team collaboration

### **Destroy Action:**
1. ✅ Empties all S3 buckets
2. ✅ Destroys all infrastructure (S3, IAM, etc.)
3. ✅ Deletes Terraform state bucket
4. ✅ Complete cleanup - nothing left behind!

---

## 📋 Prerequisites

### **One-Time Setup:**

Add these to GitHub Secrets:
```
Settings → Secrets and variables → Actions → Secrets
```

**Required Secrets:**
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

**Optional Variable:**
- `AWS_REGION`: (default: us-east-1)

---

## 🚀 HOW TO DEPLOY

### **Step 1: Trigger Deploy Workflow**

1. Go to GitHub Actions
2. Select workflow: **"Infrastructure Management"**
3. Click **"Run workflow"**
4. Select action: **`deploy`**
5. Click **"Run workflow"**

### **Step 2: Wait for Completion**

The workflow will:
```
⏳ Creating Terraform state bucket...
✅ State bucket created: terraform-state-123456789

⏳ Deploying S3 infrastructure...
✅ S3 bucket created: bankapp-security-reports-123456789
✅ IAM role created: github-actions-security-reports-role

📋 Outputs ready!
```

**Time:** ~3 minutes

### **Step 3: Copy Outputs**

At the end of the workflow, you'll see:

```
=========================================
✅ INFRASTRUCTURE DEPLOYED SUCCESSFULLY!
=========================================

📋 Add these to GitHub Variables:

AWS_REGION: us-east-1
AWS_ROLE_ARN: arn:aws:iam::123456789:role/github-actions-security-reports-role
S3_SECURITY_REPORTS_BUCKET: bankapp-security-reports-123456789

=========================================
```

### **Step 4: Add to GitHub Variables**

```
Settings → Secrets and variables → Actions → Variables
```

Click **"New repository variable"** and add:

- **Name:** `AWS_REGION`  
  **Value:** `us-east-1`

- **Name:** `AWS_ROLE_ARN`  
  **Value:** `arn:aws:iam::123456789:role/...` (from output)

- **Name:** `S3_SECURITY_REPORTS_BUCKET`  
  **Value:** `bankapp-security-reports-123456789` (from output)

### **Step 5: Setup Athena**

Follow: `COMPLETE_SETUP_GUIDE.md` → Phase 3

---

## 🗑️ HOW TO DESTROY (When Demo is Done)

### **Step 1: Trigger Destroy Workflow**

1. Go to GitHub Actions
2. Select workflow: **"Infrastructure Management"**
3. Click **"Run workflow"**
4. Select action: **`destroy`**
5. Click **"Run workflow"**

### **Step 2: Confirm Destruction**

The workflow will:
```
⏳ Emptying S3 buckets...
✅ Security reports bucket emptied

⏳ Destroying infrastructure...
✅ S3 bucket deleted
✅ IAM roles deleted
✅ All resources destroyed

⏳ Deleting state bucket...
✅ State bucket deleted: terraform-state-123456789

=========================================
✅ INFRASTRUCTURE DESTROYED SUCCESSFULLY!
=========================================
```

**Time:** ~2 minutes

### **Step 3: Remove GitHub Variables**

```
Settings → Secrets and variables → Actions → Variables
```

Delete these variables:
- ❌ `AWS_REGION`
- ❌ `AWS_ROLE_ARN`
- ❌ `S3_SECURITY_REPORTS_BUCKET`

---

## 🎯 Complete Workflow

### **For Client Demo:**

```
1. Deploy Infrastructure
   └─ Run workflow: action = deploy
   └─ Add GitHub variables
   └─ Setup Athena

2. Use the System
   └─ Run CICD pipeline multiple times
   └─ Generate test data (optional)
   └─ Setup QuickSight
   └─ Demo to client

3. Clean Up After Demo
   └─ Run workflow: action = destroy
   └─ Remove GitHub variables
   └─ Done! No AWS costs!
```

---

## 💰 Cost Savings

### **With This Workflow:**

**During Demo (1 week):**
- S3 storage: ~$0.05
- **Total: $0.05**

**After Destroy:**
- **Total: $0.00** ✅

### **Without This Workflow (Manual Cleanup):**

**Risk:**
- Forget to delete buckets
- Continue paying $0.20/month
- Over 1 year: $2.40 wasted

**With automated destroy: Save money!** 💰

---

## 🔒 What Gets Created

### **State Bucket:**
- **Name:** `terraform-state-{AWS_ACCOUNT_ID}`
- **Purpose:** Stores Terraform state file
- **Features:**
  - Versioning enabled
  - Encryption enabled
  - Auto-deleted on destroy

### **Security Reports Bucket:**
- **Name:** `bankapp-security-reports-{AWS_ACCOUNT_ID}`
- **Purpose:** Stores security scan reports
- **Features:**
  - Encryption enabled
  - Lifecycle policies
  - Auto-deleted on destroy

### **IAM Role:**
- **Name:** `github-actions-security-reports-role`
- **Purpose:** Allows GitHub Actions to upload to S3
- **Features:**
  - OIDC authentication
  - Least-privilege access
  - Auto-deleted on destroy

---

## 🆘 Troubleshooting

### **Issue: Deploy fails with "AccessDenied"**

**Solution:**
- Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are correct
- Verify IAM user has permissions:
  - `s3:*`
  - `iam:*`
  - `sts:GetCallerIdentity`

### **Issue: Destroy fails - bucket not empty**

**Solution:**
- Workflow automatically empties buckets
- If it fails, manually empty in AWS Console:
  ```bash
  aws s3 rm s3://BUCKET_NAME --recursive
  ```

### **Issue: State bucket already exists**

**Solution:**
- Workflow checks if bucket exists
- If exists, it reuses it
- No error, this is expected

---

## 📊 Comparison: Manual vs Automated

### **Manual Terraform:**

```
✅ Full control
✅ See what's happening
❌ Need Terraform installed locally
❌ Need AWS CLI configured
❌ Manual state management
❌ Risk of forgetting to destroy
```

### **Automated Workflow (This):**

```
✅ No local tools needed
✅ Automatic state management
✅ One-click deploy
✅ One-click destroy
✅ No risk of forgetting cleanup
✅ Team collaboration ready
❌ Less visibility into process
```

---

## 🎯 Best Practices

### **Before Deploy:**
- ✅ Verify AWS credentials are valid
- ✅ Check AWS account has sufficient permissions
- ✅ Review Terraform code in `terraform/security-reports-s3/`

### **During Demo:**
- ✅ Keep infrastructure running
- ✅ Run CICD pipeline multiple times
- ✅ Show client the S3 structure

### **After Demo:**
- ✅ Run destroy workflow
- ✅ Verify in AWS Console everything is deleted
- ✅ Remove GitHub variables
- ✅ Check AWS bill (should be ~$0)

---

## 🔄 State Management

### **How State Works:**

```
First Deploy:
  └─ Creates state bucket: terraform-state-123456789
  └─ Stores state: s3://terraform-state-123456789/security-reports-s3/terraform.tfstate
  └─ State tracks: S3 bucket, IAM role, policies

Subsequent Runs:
  └─ Reads state from S3
  └─ Knows what exists
  └─ Only creates/updates what changed

Destroy:
  └─ Reads state from S3
  └─ Knows what to delete
  └─ Deletes all resources
  └─ Deletes state bucket
```

---

## ✅ Success Criteria

### **After Deploy:**
- ✅ Workflow completes successfully
- ✅ Outputs show bucket name and role ARN
- ✅ Can see buckets in AWS S3 console
- ✅ Can see IAM role in AWS IAM console

### **After Destroy:**
- ✅ Workflow completes successfully
- ✅ No buckets in AWS S3 console
- ✅ No IAM role in AWS IAM console
- ✅ No ongoing AWS costs

---

## 📞 Quick Commands

### **Check if buckets exist:**
```bash
aws s3 ls | grep -E "(terraform-state|bankapp-security-reports)"
```

### **Check if IAM role exists:**
```bash
aws iam get-role --role-name github-actions-security-reports-role
```

### **Manually destroy (if workflow fails):**
```bash
cd terraform/security-reports-s3
terraform destroy -auto-approve
```

---

## 🎉 Summary

**Deploy:**
```
1. Run workflow (action = deploy)
2. Copy outputs
3. Add to GitHub variables
4. Setup Athena
5. Use the system!
```

**Destroy:**
```
1. Run workflow (action = destroy)
2. Remove GitHub variables
3. Done! Clean slate!
```

**Total Time:**
- Deploy: 5 minutes
- Destroy: 3 minutes

**Cost:**
- During demo: ~$0.05
- After destroy: $0.00

---

**🚀 You're ready to deploy and destroy with one click!**
