"""
AI Trend Intelligence Script

This script analyzes historical security scan data from Athena and provides:
1. Security Risk Score (0-100)
2. Trend Analysis (improving or degrading)
3. Remediation Recommendations
4. Predictive Alerts
5. Root Cause Analysis
"""

import json
import os
import sys
import time
import boto3
from datetime import datetime, timedelta

def run_athena_query(query, database='security_analytics'):
    """Execute Athena query and return results"""
    athena = boto3.client('athena', region_name=os.getenv('AWS_REGION', 'us-east-1'))
    
    # Start query execution
    response = athena.start_query_execution(
        QueryString=query,
        QueryExecutionContext={'Database': database},
        ResultConfiguration={
            'OutputLocation': f"s3://{os.getenv('S3_SECURITY_REPORTS_BUCKET')}/athena-results/"
        }
    )
    
    query_execution_id = response['QueryExecutionId']
    
    # Wait for query to complete
    max_attempts = 30
    for attempt in range(max_attempts):
        result = athena.get_query_execution(QueryExecutionId=query_execution_id)
        status = result['QueryExecution']['Status']['State']
        
        if status == 'SUCCEEDED':
            break
        elif status in ['FAILED', 'CANCELLED']:
            raise Exception(f"Query failed: {result['QueryExecution']['Status'].get('StateChangeReason', 'Unknown error')}")
        
        time.sleep(2)
    
    # Get query results
    results = athena.get_query_results(QueryExecutionId=query_execution_id)
    return results

def get_vulnerability_trends():
    """Get vulnerability trends over last 30 days"""
    query = """
    SELECT 
      CONCAT(year, '-', month, '-', day) as scan_date,
      SUM(CASE WHEN vuln.Severity = 'CRITICAL' THEN 1 ELSE 0 END) as critical_count,
      SUM(CASE WHEN vuln.Severity = 'HIGH' THEN 1 ELSE 0 END) as high_count,
      SUM(CASE WHEN vuln.Severity = 'MEDIUM' THEN 1 ELSE 0 END) as medium_count,
      SUM(CASE WHEN vuln.Severity = 'LOW' THEN 1 ELSE 0 END) as low_count,
      COUNT(*) as total_count
    FROM security_analytics.trivy_scans
    CROSS JOIN UNNEST(Results) AS t(result)
    CROSS JOIN UNNEST(result.Vulnerabilities) AS v(vuln)
    WHERE CAST(CONCAT(year, month, day) AS INTEGER) >= CAST(date_format(current_date - interval '30' day, '%Y%m%d') AS INTEGER)
    GROUP BY year, month, day
    ORDER BY scan_date DESC
    LIMIT 30
    """
    
    try:
        results = run_athena_query(query)
        rows = results['ResultSet']['Rows'][1:]  # Skip header
        
        trends = []
        for row in rows:
            data = row['Data']
            trends.append({
                'date': data[0].get('VarCharValue', ''),
                'critical': int(data[1].get('VarCharValue', 0)),
                'high': int(data[2].get('VarCharValue', 0)),
                'medium': int(data[3].get('VarCharValue', 0)),
                'low': int(data[4].get('VarCharValue', 0)),
                'total': int(data[5].get('VarCharValue', 0))
            })
        
        return trends
    except Exception as e:
        print(f"⚠️ Could not fetch trends from Athena: {e}")
        return []

def get_persistent_critical_issues():
    """Get CRITICAL vulnerabilities that appear in multiple scans"""
    query = """
    SELECT 
      vuln.VulnerabilityID,
      vuln.PkgName,
      vuln.Title,
      vuln.FixedVersion,
      COUNT(DISTINCT CONCAT(year, month, day)) as days_present,
      MIN(CONCAT(year, '-', month, '-', day)) as first_seen,
      MAX(CONCAT(year, '-', month, '-', day)) as last_seen
    FROM security_analytics.trivy_scans
    CROSS JOIN UNNEST(Results) AS t(result)
    CROSS JOIN UNNEST(result.Vulnerabilities) AS v(vuln)
    WHERE vuln.Severity = 'CRITICAL'
    GROUP BY vuln.VulnerabilityID, vuln.PkgName, vuln.Title, vuln.FixedVersion
    HAVING COUNT(DISTINCT CONCAT(year, month, day)) > 1
    ORDER BY days_present DESC
    LIMIT 10
    """
    
    try:
        results = run_athena_query(query)
        rows = results['ResultSet']['Rows'][1:]
        
        issues = []
        for row in rows:
            data = row['Data']
            issues.append({
                'cve_id': data[0].get('VarCharValue', ''),
                'package': data[1].get('VarCharValue', ''),
                'title': data[2].get('VarCharValue', ''),
                'fixed_version': data[3].get('VarCharValue', ''),
                'days_present': int(data[4].get('VarCharValue', 0)),
                'first_seen': data[5].get('VarCharValue', ''),
                'last_seen': data[6].get('VarCharValue', '')
            })
        
        return issues
    except Exception as e:
        print(f"⚠️ Could not fetch critical issues: {e}")
        return []

def get_secret_trends():
    """Get secret leakage trends"""
    query = """
    SELECT 
      CONCAT(year, '-', month, '-', day) as scan_date,
      COUNT(*) as secret_count,
      COUNT(DISTINCT File) as affected_files
    FROM security_analytics.gitleaks_scans
    WHERE CAST(CONCAT(year, month, day) AS INTEGER) >= CAST(date_format(current_date - interval '30' day, '%Y%m%d') AS INTEGER)
    GROUP BY year, month, day
    ORDER BY scan_date DESC
    """
    
    try:
        results = run_athena_query(query)
        rows = results['ResultSet']['Rows'][1:]
        
        secrets = []
        for row in rows:
            data = row['Data']
            secrets.append({
                'date': data[0].get('VarCharValue', ''),
                'count': int(data[1].get('VarCharValue', 0)),
                'files': int(data[2].get('VarCharValue', 0))
            })
        
        return secrets
    except Exception as e:
        print(f"⚠️ Could not fetch secret trends: {e}")
        return []

def calculate_risk_score(trends, secrets):
    """Calculate security risk score (0-100)"""
    if not trends:
        return 0, "UNKNOWN"
    
    latest = trends[0]
    
    # Weighted scoring
    vuln_score = (
        latest['critical'] * 10 +
        latest['high'] * 5 +
        latest['medium'] * 2 +
        latest['low'] * 0.5
    )
    
    # Add secret penalty
    secret_score = 0
    if secrets:
        secret_score = secrets[0]['count'] * 15
    
    raw_score = vuln_score + secret_score
    risk_score = min(100, raw_score)
    
    # Determine risk level
    if risk_score <= 20:
        risk_level = "LOW"
    elif risk_score <= 50:
        risk_level = "MEDIUM"
    elif risk_score <= 80:
        risk_level = "HIGH"
    else:
        risk_level = "CRITICAL"
    
    return risk_score, risk_level

def analyze_trend_direction(trends):
    """Determine if security is improving or degrading"""
    if len(trends) < 2:
        return "INSUFFICIENT_DATA", 0
    
    recent = trends[:7]  # Last 7 days
    older = trends[7:14] if len(trends) >= 14 else trends[7:]
    
    if not older:
        return "INSUFFICIENT_DATA", 0
    
    recent_avg = sum(t['total'] for t in recent) / len(recent)
    older_avg = sum(t['total'] for t in older) / len(older)
    
    change_pct = ((recent_avg - older_avg) / older_avg * 100) if older_avg > 0 else 0
    
    if change_pct > 10:
        return "DEGRADING", change_pct
    elif change_pct < -10:
        return "IMPROVING", change_pct
    else:
        return "STABLE", change_pct

def generate_ai_analysis(trends, critical_issues, secrets, risk_score, risk_level, trend_direction, change_pct):
    """Generate AI-powered analysis using Gemini"""
    import requests
    
    api_key = os.getenv('GEMINI_API_KEY')
    if not api_key:
        return "⚠️ GEMINI_API_KEY not set - skipping AI analysis"
    
    # Prepare data summary
    latest_trend = trends[0] if trends else {}
    
    prompt = f"""
You are a DevSecOps AI Security Analyst. Analyze this security trend data and provide actionable insights.

CURRENT STATUS:
- Risk Score: {risk_score}/100 ({risk_level})
- Trend: {trend_direction} ({change_pct:+.1f}% change)
- Latest Scan: {latest_trend.get('date', 'N/A')}
  - CRITICAL: {latest_trend.get('critical', 0)}
  - HIGH: {latest_trend.get('high', 0)}
  - MEDIUM: {latest_trend.get('medium', 0)}
  - LOW: {latest_trend.get('low', 0)}
  - Total: {latest_trend.get('total', 0)}

PERSISTENT CRITICAL ISSUES (Not Fixed):
{json.dumps(critical_issues[:3], indent=2) if critical_issues else "None"}

SECRET LEAKAGE:
{json.dumps(secrets[:3], indent=2) if secrets else "None"}

TREND DATA (Last 30 Days):
{json.dumps(trends[:10], indent=2) if trends else "None"}

Generate a CONCISE report (Max 300 words) with:

1. 🎯 EXECUTIVE SUMMARY: One sentence on overall security posture

2. 📊 TREND ANALYSIS: What's the trend telling us? (2-3 sentences)

3. 🚨 TOP 3 PRIORITIES: Most urgent issues to fix (be specific with CVE IDs and packages)

4. 💡 REMEDIATION PLAN: Step-by-step fixes for top priorities

5. 🔮 PREDICTIONS: What will happen if current trend continues?

6. 🔍 ROOT CAUSE: Why is the trend going this direction?

Be specific, actionable, and use the actual data provided. Focus on WHAT TO DO, not just describing the problem.
"""
    
    try:
        url = f"https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key={api_key}"
        
        payload = {
            "contents": [{
                "role": "user",
                "parts": [{"text": prompt}]
            }]
        }
        
        response = requests.post(url, json=payload, timeout=60)
        
        if response.status_code == 200:
            return response.json()["candidates"][0]["content"]["parts"][0]["text"]
        else:
            return f"⚠️ AI API Error: {response.text}"
    
    except Exception as e:
        return f"⚠️ AI Analysis failed: {e}"

def main():
    print("🤖 AI Trend Intelligence - Starting Analysis...")
    print("=" * 60)
    
    # Fetch data from Athena
    print("\n📊 Fetching vulnerability trends from Athena...")
    trends = get_vulnerability_trends()
    
    print("🔍 Fetching persistent critical issues...")
    critical_issues = get_persistent_critical_issues()
    
    print("🔐 Fetching secret leakage data...")
    secrets = get_secret_trends()
    
    # Calculate risk score
    print("\n⚖️ Calculating security risk score...")
    risk_score, risk_level = calculate_risk_score(trends, secrets)
    
    # Analyze trend direction
    print("📈 Analyzing trend direction...")
    trend_direction, change_pct = analyze_trend_direction(trends)
    
    # Generate AI analysis
    print("\n🤖 Generating AI-powered insights...")
    ai_analysis = generate_ai_analysis(
        trends, critical_issues, secrets,
        risk_score, risk_level, trend_direction, change_pct
    )
    
    # Output report
    print("\n" + "=" * 60)
    print("🛡️ SECURITY INTELLIGENCE REPORT")
    print("=" * 60)
    print(f"\n📊 RISK SCORE: {risk_score}/100 - {risk_level}")
    print(f"📈 TREND: {trend_direction} ({change_pct:+.1f}% change)")
    print(f"📅 Analysis Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    print("\n" + "-" * 60)
    print(ai_analysis)
    print("-" * 60)
    
    # Save to file
    report = {
        "timestamp": datetime.now().isoformat(),
        "risk_score": risk_score,
        "risk_level": risk_level,
        "trend_direction": trend_direction,
        "change_percentage": change_pct,
        "latest_scan": trends[0] if trends else {},
        "persistent_critical_issues": critical_issues,
        "secret_trends": secrets[:5],
        "ai_analysis": ai_analysis
    }
    
    with open('ai-trend-report.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    print("\n✅ Report saved to: ai-trend-report.json")
    
    # Write to GitHub Step Summary if available
    if os.getenv('GITHUB_STEP_SUMMARY'):
        with open(os.getenv('GITHUB_STEP_SUMMARY'), 'a') as f:
            f.write(f"\n## 🤖 AI Trend Intelligence Report\n\n")
            f.write(f"**Risk Score:** {risk_score}/100 - {risk_level}\n\n")
            f.write(f"**Trend:** {trend_direction} ({change_pct:+.1f}% change)\n\n")
            f.write(f"### AI Analysis\n\n{ai_analysis}\n")
    
    print("\n🎉 Analysis complete!")

if __name__ == "__main__":
    main()
