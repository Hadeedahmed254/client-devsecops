import json
import os
import requests
import sys

def get_gemini_response(prompt, api_key):
    url = (
        "https://generativelanguage.googleapis.com/"
        "v1/models/gemini-2.5-flash:generateContent"
        f"?key={api_key}"
    )

    headers = {
        "Content-Type": "application/json"
    }

    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [{"text": prompt}]
            }
        ]
    }

    response = requests.post(url, headers=headers, json=payload, timeout=60)

    if response.status_code == 200:
        return response.json()["candidates"][0]["content"]["parts"][0]["text"]
    else:
        return f"Error from AI API: {response.text}"





def get_sonar_data(host_url, token, project_key):
    try:
        auth = (token, '')

        # Quality Gate Status
        status_url = f"{host_url}/api/qualitygates/project_status?projectKey={project_key}"
        status_res = requests.get(status_url, auth=auth)
        status_data = status_res.json()

        # Top Critical / Blocker Issues
        issues_url = (
            f"{host_url}/api/issues/search?"
            f"componentKeys={project_key}&severities=CRITICAL,BLOCKER&resolved=false"
        )
        issues_res = requests.get(issues_url, auth=auth)
        issues_data = issues_res.json()

        return {
            "status": status_data.get('projectStatus', {}).get('status', 'UNKNOWN'),
            "issues": issues_data.get('issues', [])[:5]
        }

    except Exception as e:
        return {"error": str(e)}


def main():
    trivy_file = 'fs-report.json'
    snyk_file = 'snyk-report.json'

    trivy_data = {}
    snyk_data = {}

    if os.path.exists(trivy_file):
        with open(trivy_file, 'r') as f:
            trivy_data = json.load(f)

    if os.path.exists(snyk_file):
        try:
            with open(snyk_file, 'r') as f:
                snyk_data = json.load(f)
        except Exception:
            snyk_data = {"error": "Failed to parse Snyk report"}

    # SonarQube
    sonar_host = os.getenv('SONAR_HOST_URL')
    sonar_token = os.getenv('SONAR_TOKEN')
    sonar_project = "GC-Bank"

    sonar_summary = "SONARQUBE ANALYSIS:\n"

    if sonar_host and sonar_token:
        sonar_data = get_sonar_data(sonar_host, sonar_token, sonar_project)
        if 'error' in sonar_data:
            sonar_summary += f"Error: {sonar_data['error']}\n"
        else:
            sonar_summary += f"- Quality Gate Status: {sonar_data['status']}\n"
            for issue in sonar_data['issues']:
                sonar_summary += (
                    f"  * [{issue.get('severity')}] "
                    f"{issue.get('message')} "
                    f"(File: {issue.get('component')})\n"
                )
    else:
        sonar_summary += "SonarQube credentials missing. Skipping analysis.\n"

    # Trivy Summary
    vulnerabilities_summary = "TRIVY SCAN SUMMARY:\n"

    if 'Results' in trivy_data:
        for result in trivy_data['Results']:
            target = result.get('Target', 'Unknown')
            vulns = result.get('Vulnerabilities', [])
            vulnerabilities_summary += f"- {target}: {len(vulns)} vulnerabilities found\n"
            for v in vulns[:5]:
                vulnerabilities_summary += (
                    f"  * [{v.get('Severity')}] "
                    f"{v.get('VulnerabilityID')} "
                    f"{v.get('PkgName')} - {v.get('Title')}\n"
                )
    else:
        vulnerabilities_summary += "No Trivy results found.\n"

    # Snyk Summary
    vulnerabilities_summary += "\nSNYK SCAN SUMMARY:\n"

    if 'vulnerabilities' in snyk_data:
        vulns = snyk_data.get('vulnerabilities', [])
        vulnerabilities_summary += f"Found {len(vulns)} vulnerabilities\n"
        for v in vulns[:5]:
            vulnerabilities_summary += (
                f"  * [{v.get('severity', '').upper()}] "
                f"{v.get('id')} "
                f"{v.get('packageName')} - {v.get('title')}\n"
            )
    else:
        vulnerabilities_summary += "No Snyk vulnerabilities found.\n"

    prompt = f"""
    You are a DevSecOps AI Assistant. Your task is to act as a post-scan intelligence layer.
    Analyze these results from TRIVY, SNYK, and SONARQUBE for 'BankApp'.
    
    {vulnerabilities_summary}
    
    {sonar_summary}
    
    Generate a CONCISE 'Executive Security Dashboard' (Max 250 words):
    1. 🛡️ OVERALL STATUS: One sentence on the security posture.
    2. 🚨 TOP 3 RISKS: Very brief, human-readable explanations of the 3 most dangerous issues.
    3. 💡 ACTIONABLE FIXES:
       - Update [Library] to [Version] (pom.xml)
       - Refactor [File] to fix [Sonar Issue]
       - Quick Dockerfile security tip.
    
    Use a clean Markdown Table or List format. Keep it punchy and professional for a high-level client demo.
    """

    api_key = os.getenv('GEMINI_API_KEY')
    if not api_key:
        print("❌ GEMINI_API_KEY is missing")
        sys.exit(1)

    print("🤖 Sending scan results to Gemini AI...")
    ai_report = get_gemini_response(prompt, api_key)

    summary_file = os.getenv('GITHUB_STEP_SUMMARY')
    if summary_file:
        with open(summary_file, 'a', encoding='utf-8') as f:
            f.write("\n\n## 🤖 AI Security Intelligence Report\n")
            f.write(ai_report)

    with open('AI_SECURITY_REPORT.md', 'w', encoding='utf-8') as f:
        f.write(ai_report)

    print("✅ AI Security Report generated successfully")


if __name__ == "__main__":
    main()
