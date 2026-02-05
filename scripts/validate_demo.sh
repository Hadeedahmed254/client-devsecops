#!/bin/bash

# 🎯 PRE-DEMO VALIDATION SCRIPT
# Run this after deployment to verify everything is ready

echo "🔍 GRAFANA DEMO VALIDATION"
echo "=========================================="

# Check 1: Verify S3 bucket structure
echo ""
echo "📦 Checking S3 Folder Structure..."
BUCKET="bankapp-security-reports-211125523455"

if aws s3 ls "s3://${BUCKET}/trivy/" 2>/dev/null | grep -q "PRE"; then
    echo "✅ trivy/ folder exists"
else
    echo "❌ trivy/ folder missing"
fi

if aws s3 ls "s3://${BUCKET}/gitleaks/" 2>/dev/null | grep -q "PRE"; then
    echo "✅ gitleaks/ folder exists"
else
    echo "❌ gitleaks/ folder missing"
fi

if aws s3 ls "s3://${BUCKET}/metadata/" 2>/dev/null | grep -q "PRE"; then
    echo "✅ metadata/ folder exists"
else
    echo "❌ metadata/ folder missing"
fi

# Check 2: Verify Athena tables
echo ""
echo "🗄️ Checking Athena Tables..."
TABLES=$(aws athena start-query-execution \
    --query-string "SHOW TABLES IN security_analytics" \
    --result-configuration "OutputLocation=s3://${BUCKET}/athena-results/" \
    --query-execution-context "Database=security_analytics" \
    --region us-east-1 \
    --query 'QueryExecutionId' \
    --output text)

sleep 5

RESULT=$(aws athena get-query-results \
    --query-execution-id $TABLES \
    --region us-east-1 \
    --query 'ResultSet.Rows[*].Data[0].VarCharValue' \
    --output text)

if echo "$RESULT" | grep -q "trivy_scans"; then
    echo "✅ trivy_scans table exists"
else
    echo "❌ trivy_scans table missing"
fi

if echo "$RESULT" | grep -q "gitleaks_scans"; then
    echo "✅ gitleaks_scans table exists"
else
    echo "❌ gitleaks_scans table missing"
fi

# Check 3: Verify data count
echo ""
echo "📊 Checking Data Count..."
COUNT_QUERY=$(aws athena start-query-execution \
    --query-string "SELECT COUNT(*) FROM security_analytics.trivy_scans" \
    --result-configuration "OutputLocation=s3://${BUCKET}/athena-results/" \
    --query-execution-context "Database=security_analytics" \
    --region us-east-1 \
    --query 'QueryExecutionId' \
    --output text)

sleep 10

COUNT=$(aws athena get-query-results \
    --query-execution-id $COUNT_QUERY \
    --region us-east-1 \
    --query 'ResultSet.Rows[1].Data[0].VarCharValue' \
    --output text)

echo "Trivy scans found: $COUNT"

if [ "$COUNT" -eq "30" ]; then
    echo "✅ Perfect! 30 days of demo data confirmed"
elif [ "$COUNT" -gt "0" ]; then
    echo "⚠️ Found $COUNT records (expected 30)"
else
    echo "❌ No data found - run 'Generate Demo Data' workflow"
fi

# Check 4: Test the exact Grafana query
echo ""
echo "📈 Testing Grafana Query..."
GRAFANA_QUERY=$(aws athena start-query-execution \
    --query-string "SELECT CAST(CONCAT(year, '-', month, '-', day) AS TIMESTAMP) as time, COUNT(*) as value FROM security_analytics.trivy_scans GROUP BY year, month, day ORDER BY time" \
    --result-configuration "OutputLocation=s3://${BUCKET}/athena-results/" \
    --query-execution-context "Database=security_analytics" \
    --region us-east-1 \
    --query 'QueryExecutionId' \
    --output text)

sleep 10

TREND_DATA=$(aws athena get-query-results \
    --query-execution-id $GRAFANA_QUERY \
    --region us-east-1 \
    --query 'ResultSet.Rows[1:3]' \
    --output json)

if echo "$TREND_DATA" | grep -q "time"; then
    echo "✅ Grafana query works! Sample data:"
    echo "$TREND_DATA" | jq -r '.[] | "\(.Data[0].VarCharValue): \(.Data[1].VarCharValue) vulnerabilities"'
else
    echo "❌ Grafana query failed"
fi

# Final Summary
echo ""
echo "=========================================="
echo "🎯 DEMO READINESS SUMMARY"
echo "=========================================="
echo ""
echo "If all checks show ✅, your demo is ready!"
echo ""
echo "Next steps:"
echo "1. Open Grafana URL from GitHub Actions"
echo "2. Wait 5 minutes after deployment"
echo "3. Navigate to 'Security Intelligence Dashboard'"
echo "4. Show client the beautiful trend analysis!"
echo ""
echo "=========================================="
