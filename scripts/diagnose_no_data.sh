#!/bin/bash

# 🔍 GRAFANA NO DATA - DIAGNOSTIC SCRIPT
# Run this to find out why Grafana shows no data

echo "=========================================="
echo "🔍 GRAFANA NO DATA DIAGNOSTIC"
echo "=========================================="
echo ""

BUCKET="bankapp-security-reports-211125523455"
REGION="us-east-1"

# Step 1: Check if S3 data exists
echo "📦 Step 1: Checking S3 Data..."
echo "Looking for trivy reports..."
TRIVY_COUNT=$(aws s3 ls s3://${BUCKET}/trivy/ --recursive | grep "trivy-report.json" | wc -l)
echo "Found: $TRIVY_COUNT trivy reports"

echo "Looking for gitleaks reports..."
GITLEAKS_COUNT=$(aws s3 ls s3://${BUCKET}/gitleaks/ --recursive | grep "gitleaks-report.json" | wc -l)
echo "Found: $GITLEAKS_COUNT gitleaks reports"

if [ "$TRIVY_COUNT" -eq "0" ]; then
    echo "❌ NO DATA IN S3!"
    echo "   Solution: Run 'CICD Pipeline' or 'Generate Demo Data' workflow"
    exit 1
else
    echo "✅ S3 data exists"
fi

echo ""

# Step 2: Check if Athena database exists
echo "🗄️ Step 2: Checking Athena Database..."
DB_CHECK=$(aws athena start-query-execution \
    --query-string "SHOW DATABASES" \
    --result-configuration "OutputLocation=s3://${BUCKET}/athena-results/" \
    --region ${REGION} \
    --query 'QueryExecutionId' \
    --output text 2>/dev/null)

if [ -z "$DB_CHECK" ]; then
    echo "❌ Cannot query Athena"
    exit 1
fi

sleep 5

DB_RESULT=$(aws athena get-query-results \
    --query-execution-id $DB_CHECK \
    --region ${REGION} \
    --query 'ResultSet.Rows[*].Data[0].VarCharValue' \
    --output text)

if echo "$DB_RESULT" | grep -q "security_analytics"; then
    echo "✅ Database 'security_analytics' exists"
else
    echo "❌ Database 'security_analytics' NOT FOUND!"
    echo "   Solution: Run 'Athena Database Management → setup'"
    exit 1
fi

echo ""

# Step 3: Check if tables exist
echo "📋 Step 3: Checking Athena Tables..."
TABLE_CHECK=$(aws athena start-query-execution \
    --query-string "SHOW TABLES IN security_analytics" \
    --result-configuration "OutputLocation=s3://${BUCKET}/athena-results/" \
    --query-execution-context "Database=security_analytics" \
    --region ${REGION} \
    --query 'QueryExecutionId' \
    --output text)

sleep 5

TABLE_RESULT=$(aws athena get-query-results \
    --query-execution-id $TABLE_CHECK \
    --region ${REGION} \
    --query 'ResultSet.Rows[*].Data[0].VarCharValue' \
    --output text)

if echo "$TABLE_RESULT" | grep -q "trivy_scans"; then
    echo "✅ Table 'trivy_scans' exists"
else
    echo "❌ Table 'trivy_scans' NOT FOUND!"
    echo "   Solution: Run 'Athena Database Management → setup'"
    exit 1
fi

echo ""

# Step 4: Check if Athena can query the data
echo "🔍 Step 4: Testing Athena Query..."
QUERY_ID=$(aws athena start-query-execution \
    --query-string "SELECT COUNT(*) FROM security_analytics.trivy_scans" \
    --result-configuration "OutputLocation=s3://${BUCKET}/athena-results/" \
    --query-execution-context "Database=security_analytics" \
    --region ${REGION} \
    --query 'QueryExecutionId' \
    --output text)

echo "Query ID: $QUERY_ID"
echo "Waiting for query to complete..."

# Wait for query
for i in {1..30}; do
    STATE=$(aws athena get-query-execution \
        --query-execution-id $QUERY_ID \
        --region ${REGION} \
        --query 'QueryExecution.Status.State' \
        --output text)
    
    echo "Query state: $STATE"
    
    if [ "$STATE" = "SUCCEEDED" ]; then
        break
    elif [ "$STATE" = "FAILED" ]; then
        ERROR=$(aws athena get-query-execution \
            --query-execution-id $QUERY_ID \
            --region ${REGION} \
            --query 'QueryExecution.Status.StateChangeReason' \
            --output text)
        echo "❌ Query FAILED!"
        echo "Error: $ERROR"
        exit 1
    fi
    
    sleep 2
done

if [ "$STATE" = "SUCCEEDED" ]; then
    COUNT=$(aws athena get-query-results \
        --query-execution-id $QUERY_ID \
        --region ${REGION} \
        --query 'ResultSet.Rows[1].Data[0].VarCharValue' \
        --output text)
    
    echo "✅ Query succeeded!"
    echo "📊 Record count: $COUNT"
    
    if [ "$COUNT" -eq "0" ]; then
        echo "❌ ATHENA RETURNS ZERO RECORDS!"
        echo ""
        echo "Possible causes:"
        echo "1. Partitions not discovered"
        echo "   Solution: Run 'MSCK REPAIR TABLE security_analytics.trivy_scans'"
        echo ""
        echo "2. Data in wrong S3 location"
        echo "   Check: S3 data should be in trivy/YYYY/MM/DD/ format"
        echo ""
        echo "3. Table LOCATION mismatch"
        echo "   Check: Table should point to s3://${BUCKET}/trivy/"
    fi
else
    echo "❌ Query timed out"
fi

echo ""

# Step 5: Check Grafana data source configuration
echo "🎨 Step 5: Grafana Configuration Check..."
echo "Expected Grafana data source config:"
echo "  - Type: grafana-athena-datasource"
echo "  - Auth: ec2_iam_role"
echo "  - Database: security_analytics"
echo "  - Output: s3://${BUCKET}/athena-results/"
echo ""
echo "To verify, SSH into Grafana EC2 and check:"
echo "  cat /home/ubuntu/grafana/provisioning/datasources/athena.yaml"

echo ""
echo "=========================================="
echo "🎯 DIAGNOSTIC SUMMARY"
echo "=========================================="
echo "S3 Data: $TRIVY_COUNT files"
echo "Athena Count: $COUNT records"
echo ""

if [ "$COUNT" -gt "0" ]; then
    echo "✅ DATA IS QUERYABLE!"
    echo ""
    echo "If Grafana still shows 'No Data':"
    echo "1. Wait 5 minutes for Grafana plugin to initialize"
    echo "2. Check Grafana logs: docker logs grafana"
    echo "3. Verify IAM role has AthenaFullAccess + S3FullAccess"
    echo "4. Restart Grafana: docker restart grafana"
else
    echo "❌ NO DATA IN ATHENA!"
    echo ""
    echo "Next steps:"
    echo "1. Verify S3 folder structure matches table LOCATION"
    echo "2. Run: MSCK REPAIR TABLE security_analytics.trivy_scans"
    echo "3. Check table definition in athena/setup.sql"
fi

echo "=========================================="
