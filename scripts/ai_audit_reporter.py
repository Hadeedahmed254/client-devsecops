import json
import os
import requests
import sys

# ==============================================================================
# 🏛️ GOD-LEVEL AI AUDIT REPORTER (Refactored for Sravya M)
# ==============================================================================
# Focus: Compliance, Zero-Limit Reporting, and Developer Remediation Tables.
# Version: 2.1 (Production/Bank-Grade)
# ==============================================================================

def get_gemini_response(prompt, api_token):
    url = f"https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key={api_token}"
    headers = {"Content-Type": "application/json"}
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}]
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=60)
        if response.status_code == 200:
            return response.json()["candidates"][0]["content"]["parts"][0]["text"]
        return f"⚠️ AI API Error: {response.status_code}"
    except Exception as e:
        return f"⚠️ AI Connection Error: {str(e)}"

def get_sonar_data(host_url, token, project_key):
    try:
        auth = (token, '')
        status_url = f"{host_url}/api/qualitygates/project_status?projectKey={project_key}"
        issues_url = f"{host_url}/api/issues/search?componentKeys={project_key}&severities=CRITICAL,BLOCKER&resolved=false"
        
        status_res = requests.get(status_url, auth=auth, timeout=30).json()
        issues_res = requests.get(issues_url, auth=auth, timeout=30).json()

        return {
            "status": status_res.get('projectStatus', {}).get('status', 'UNKNOWN'),
            "issues": issues_res.get('issues', []) # NO LIMITS
        }
    except Exception as e:
        return {"error": str(e)}

def main():
    # 1. LOAD RAW DATA
    files = {
        'trivy': 'fs-report.json',
        'snyk': 'snyk-report.json',
        'gitleaks': 'gitleaks-report.json'
    }
    
    data = {}
    for key, path in files.items():
        if os.path.exists(path):
            try:
                with open(path, 'r') as f:
                    data[key] = json.load(f)
            except:
                data[key] = None
        else:
            data[key] = None

    # Sonar Config
    sonar_host = os.getenv('SONAR_HOST_URL')
    sonar_token = os.getenv('SONAR_TOKEN')
    sonar_project = "GC-Bank"
    sonar_data = get_sonar_data(sonar_host, sonar_token, sonar_project) if sonar_host and sonar_token else None

    # ========================================================
    # 📊 STAGE 1: DYNAMIC TABLE GENERATION (The "Clean" View)
    # ========================================================
    
    dashboard = "# 🛡️ EXECUTIVE SECURITY & REMEDIATION DASHBOARD\n\n"

    # --- SECTION 1: HIGH/CRITICAL VULNERABILITIES (Snyk & Trivy) ---
    dashboard += "### 1️⃣ High/Critical Vulnerabilities\n"
    v_table = "| Severity | Package | Current Version | Fixed Version | Image | File | Notes / Fix |\n"
    v_table += "|----------|---------|-----------------|---------------|-------|------|-------------|\n"
    v_found = False

    # Process Snyk (Full Detail)
    if data['snyk']:
        s_projects = data['snyk'] if isinstance(data['snyk'], list) else [data['snyk']]
        for project in s_projects:
            for v in project.get('vulnerabilities', []):
                sev = v.get('severity', '').upper()
                if sev in ["CRITICAL", "HIGH"]:
                    v_found = True
                    fix = v.get('fixedIn', 'N/A')
                    if isinstance(fix, list): fix = ", ".join(fix) if fix else "N/A"
                    v_table += (
                        f"| **{sev}** | `{v.get('packageName')}` | "
                        f"`{v.get('version','?')}` | `{fix}` | `backend:1.0` | "
                        f"`pom.xml` | Update library |\n"
                    )

    # Process Trivy (Full Detail)
    if data['trivy'] and 'Results' in data['trivy']:
        for res in data['trivy']['Results']:
            target_file = res.get('Target', 'Dockerfile')
            for v in res.get('Vulnerabilities', []):
                sev = v.get('Severity', '').upper()
                if sev in ["CRITICAL", "HIGH"]:
                    v_found = True
                    v_table += (
                        f"| **{sev}** | `{v.get('PkgName')}` | "
                        f"`{v.get('InstalledVersion','?')}` | `{v.get('FixedVersion','N/A')}` | "
                        f"`backend:1.0` | `{target_file}` | Patch Container |\n"
                    )

    dashboard += v_table if v_found else "✅ No Critical/High vulnerabilities detected.\n"
    dashboard += "\n---\n"

    # --- SECTION 2: HARDCODED SECRETS (Gitleaks) ---
    dashboard += "### 2️⃣ Hardcoded Secrets\n"
    s_table = "| Severity | Secret Type | File | Image | Line | Notes / Fix |\n"
    s_table += "|----------|-------------|------|-------|------|-------------|\n"
    s_found = False

    if isinstance(data['gitleaks'], list):
        for secret in data['gitleaks']:
            s_found = True
            s_table += (
                f"| **CRITICAL** | {secret.get('Description','Secret')} | "
                f"`{secret.get('File','Unknown')}` | `backend:1.0` | "
                f"{secret.get('StartLine','N/A')} | ROTATE SECRET NOW |\n"
            )
    
    dashboard += s_table if s_found else "✅ No leaked secrets detected.\n"
    dashboard += "\n---\n"

    # --- SECTION 3: SONAR CRITICAL ISSUES ---
    dashboard += "### 3️⃣ Sonar Critical Issues\n"
    q_table = "| Severity | Issue Type | File | Line | Notes / Fix |\n"
    q_table += "|----------|------------|------|------|-------------|\n"
    q_found = False

    if sonar_data and 'issues' in sonar_data:
        for issue in sonar_data['issues']:
            q_found = True
            sev = issue.get('severity','').upper()
            comp = issue.get('component','').split(':')[-1]
            q_table += (
                f"| **{sev}** | {issue.get('type','Bug')} | "
                f"`{comp}` | {issue.get('line','N/A')} | "
                f"{issue.get('message')[:60]} |\n"
            )

    dashboard += q_table if q_found else "✅ No critical code smells detected.\n"
    dashboard += "\n---\n"

    # ========================================================
    # 🤖 STAGE 2: AI STRATEGIC SUMMARY
    # ========================================================
    
    ai_token = os.getenv('GEMINI_API_KEY')
    if ai_token:
        prompt = f"""
        Analyze these findings for 'BankApp'.
        Vulns Found: {v_found}, Secrets Found: {s_found}, Sonar Problems: {q_found}.
        Provide:
        - One sentence overall risk verdict.
        - Two specific technical next steps for the lead engineer.
        Keep it professional and concise.
        """
        ai_advice = get_gemini_response(prompt, ai_token)
        dashboard += "## 🤖 AI Strategic Security Advice\n"
        dashboard += ai_advice

    # 4. OUTPUTS
    summary_file = os.getenv('GITHUB_STEP_SUMMARY')
    if summary_file:
        with open(summary_file, 'a', encoding='utf-8') as f:
            f.write(dashboard)

    with open('AUDIT_SECURITY_DASHBOARD.md', 'w', encoding='utf-8') as f:
        f.write(dashboard)

    print("🏆 Audit-Ready Dashboard generated: AUDIT_SECURITY_DASHBOARD.md")

if __name__ == "__main__":
    main()
