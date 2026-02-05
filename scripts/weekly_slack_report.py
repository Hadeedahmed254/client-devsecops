"""
Weekly Slack Security Report

Sends automated weekly security intelligence reports to Slack
Includes risk score, trends, top priorities, and AI insights
"""

import json
import os
import sys
import requests
from datetime import datetime

def send_slack_message(webhook_url, message):
    """Send message to Slack via webhook"""
    try:
        response = requests.post(
            webhook_url,
            json={"text": message},
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        
        if response.status_code == 200:
            return True
        else:
            print(f"⚠️ Slack API error: {response.status_code} - {response.text}")
            return False
    
    except Exception as e:
        print(f"❌ Failed to send Slack message: {e}")
        return False

def load_trend_report():
    """Load the latest AI trend report"""
    try:
        with open('ai-trend-report.json', 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print("⚠️ No trend report found. Run ai_trend_intelligence.py first.")
        return None
    except Exception as e:
        print(f"❌ Error loading report: {e}")
        return None

def format_slack_message(report):
    """Format report data into Slack message"""
    
    risk_score = report.get('risk_score', 0)
    risk_level = report.get('risk_level', 'UNKNOWN')
    trend_direction = report.get('trend_direction', 'UNKNOWN')
    change_pct = report.get('change_percentage', 0)
    latest_scan = report.get('latest_scan', {})
    critical_issues = report.get('persistent_critical_issues', [])
    
    # Risk level emoji
    risk_emoji = {
        'LOW': '✅',
        'MEDIUM': '⚠️',
        'HIGH': '🚨',
        'CRITICAL': '🔥'
    }.get(risk_level, '❓')
    
    # Trend emoji
    if trend_direction == 'IMPROVING':
        trend_emoji = '📉'
    elif trend_direction == 'DEGRADING':
        trend_emoji = '📈'
    else:
        trend_emoji = '➡️'
    
    # Build message
    message = f"""
🔒 *Security Intelligence Report - Week of {datetime.now().strftime('%B %d, %Y')}*

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 *SECURITY RISK SCORE:* {risk_score}/100 {risk_emoji} *{risk_level} RISK*

{trend_emoji} *TREND:* {trend_direction} ({change_pct:+.1f}% change vs last week)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📈 *CURRENT VULNERABILITIES:*
• 🔴 CRITICAL: {latest_scan.get('critical', 0)}
• 🟠 HIGH: {latest_scan.get('high', 0)}
• 🟡 MEDIUM: {latest_scan.get('medium', 0)}
• 🟢 LOW: {latest_scan.get('low', 0)}
• 📊 TOTAL: {latest_scan.get('total', 0)}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""
    
    # Add persistent critical issues
    if critical_issues:
        message += "\n🚨 *PERSISTENT CRITICAL ISSUES (Not Fixed):*\n"
        for i, issue in enumerate(critical_issues[:3], 1):
            days = issue.get('days_present', 0)
            message += f"\n{i}. *{issue.get('cve_id', 'Unknown')}* in `{issue.get('package', 'Unknown')}`"
            message += f"\n   • Present for: *{days} days* ⏰"
            message += f"\n   • Fix: Upgrade to `{issue.get('fixed_version', 'Unknown')}`\n"
    
    message += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    # Add AI insights (first 500 chars)
    ai_analysis = report.get('ai_analysis', '')
    if ai_analysis and ai_analysis != '':
        # Extract just the executive summary and top priorities
        lines = ai_analysis.split('\n')
        summary_lines = [line for line in lines if line.strip()][:10]
        message += "\n🤖 *AI INSIGHTS:*\n"
        message += '\n'.join(summary_lines[:10])
        message += "\n"
    
    message += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    message += f"\n📅 Report generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}"
    message += "\n🔗 View full report in GitHub Actions"
    
    return message

def main():
    print("📨 Weekly Slack Security Report")
    print("=" * 60)
    
    # Get Slack webhook URL
    webhook_url = os.getenv('SLACK_WEBHOOK_URL')
    if not webhook_url:
        print("❌ Error: SLACK_WEBHOOK_URL environment variable not set")
        print("\nTo set up Slack webhook:")
        print("1. Go to https://api.slack.com/apps")
        print("2. Create new app → Incoming Webhooks")
        print("3. Add webhook to workspace")
        print("4. Copy webhook URL")
        print("5. Add to GitHub Secrets as SLACK_WEBHOOK_URL")
        sys.exit(1)
    
    # Load trend report
    print("📊 Loading trend analysis report...")
    report = load_trend_report()
    
    if not report:
        print("❌ No report data available")
        sys.exit(1)
    
    # Format message
    print("✍️ Formatting Slack message...")
    message = format_slack_message(report)
    
    # Send to Slack
    print("📤 Sending to Slack...")
    success = send_slack_message(webhook_url, message)
    
    if success:
        print("✅ Weekly report sent to Slack successfully!")
    else:
        print("❌ Failed to send report to Slack")
        sys.exit(1)

if __name__ == "__main__":
    main()
