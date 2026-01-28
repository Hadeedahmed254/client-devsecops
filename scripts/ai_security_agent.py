import json
import os
import requests
import sys

def get_gemini_response(prompt, api_key):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}"
    headers = {'Content-Type': 'application/json'}
    payload = {
        "contents": [{
            "parts": [{"text": prompt}]
        }]
    }
    response = requests.post(url, json=payload, headers=headers)
    if response.status_code == 200:
        return response.json()['candidates'][0]['content']['parts'][0]['text']
    else:
        return f"Error from AI API: {response.text}"

def get_sonar_data(host_url, token, project_key):
    try:
        # Get Quality Gate Status
        status_url = f"{host_url}/api/qualitygates/project_status?projectKey={project_key}"
        auth = (token, '')
        status_res = requests.get(status_url, auth=auth)
        status_data = status_res.json()
        
        # Get Top Issues
        issues_url = f"{host_url}/api/issues/search?componentKeys={project_key}&severities=CRITICAL,BLOCKER&resolved=false"
        issues_res = requests.get(issues_url, auth=auth)
        issues_data = issues_res.json()
        
        return {
            "status": status_data.get('projectStatus', {}).get('status', 'UNKNOWN'),
            "conditions": status_data.get('projectStatus', {}).get('conditions', []),
            "issues": issues_data.get('issues', [])[:5] # Top 5
        }
    except Exception as e:
        return {"error": str(e)}

def main():
    trivy_file = 'fs-report.json'
    snyk_file = 'snyk-report.json'
    
    trivy_data = {}
    if os.path.exists(trivy_file):
        with open(trivy_file, 'r') as f:
            trivy_data = json.load(f)
            
    snyk_data = {}
    if os.path.exists(snyk_file):
        with open(snyk_file, 'r') as f:
            try:
                snyk_data = json.load(f)
            except:
                snyk_data = {"error": "Could not parse Snyk JSON"}

    # SonarQube Data
    sonar_host = os.getenv('SONAR_HOST_URL')
    sonar_token = os.getenv('SONAR_TOKEN')
    sonar_project = "GC-Bank"
    sonar_summary = "SONARQUBE ANALYSIS:\n"
    
    if sonar_host and sonar_token:
        print(f"Fetching data from SonarQube at {sonar_host}...")
        data = get_sonar_data(sonar_host, sonar_token, sonar_project)
        if 'error' in data:
            sonar_summary += f"Error fetching Sonar data: {data['error']}\n"
        else:
            sonar_summary += f"- Quality Gate Status: {data['status']}\n"
            for issue in data['issues']:
                sonar_summary += f"  * [{issue.get('severity')}] {issue.get('message')} (File: {issue.get('component')})\n"
    else:
        sonar_summary += "SonarQube credentials missing. Skipping Sonar analysis.\n"

    # Prepare a condensed version of the logs for the AI
    vulnerabilities_summary = "TRIVY SCAN SUMMARY:\n"
    if 'Results' in trivy_data:
        for result in trivy_data['Results']:
            target = result.get('Target', 'Unknown')
            vulns = result.get('Vulnerabilities', [])
            vulnerabilities_summary += f"- Target: {target}, Found {len(vulns)} vulnerabilities.\n"
            for v in vulns[:5]: # Top 5
                vulnerabilities_summary += f"  * [{v.get('Severity')}] {v.get('VulnerabilityID')}: {v.get('PkgName')} - {v.get('Title')}\n"
    else:
        vulnerabilities_summary += "No Trivy vulnerabilities found or file missing.\n"

    vulnerabilities_summary += "\nSNYK SCAN SUMMARY:\n"
    if 'vulnerabilities' in snyk_data:
        vulns = snyk_data.get('vulnerabilities', [])
        vulnerabilities_summary += f"Found {len(vulns)} vulnerabilities.\n"
        for v in vulns[:5]: # Top 5
            vulnerabilities_summary += f"  * [{v.get('severity').upper()}] {v.get('id')}: {v.get('packageName')} - {v.get('title')}\n"
    else:
        vulnerabilities_summary += "No Snyk vulnerabilities found or file missing.\n"

    # AI Prompt
    prompt = f"""
    You are a DevSecOps AI Assistant. Your task is to act as a post-scan intelligence layer for a CI/CD pipeline.
    Analyze the following security and code quality scan results from TRIVY, SNYK, and SONARQUBE for a Java application (BankApp).
    
    {vulnerabilities_summary}
    
    {sonar_summary}
    
    Based on these combined results, provide a comprehensive report for the developers:
    1. EXPLAIN: What are the most critical issues across all tools? Explain them in simple, human-readable terms that a client can understand.
    2. ANALYZE: How do these vulnerabilities and code quality issues interact? (e.g., does a bad dependency combine with poor code logic?)
    3. SUGGEST FIXES: 
       - Provide specific dependency updates for pom.xml.
       - Provide specific code snippets or refactoring advice to fix the SonarQube issues.
       - Suggest a specific Dockerfile improvement if relevant.
    
    Format your response in a beautiful Markdown format with emojis and clear headings.
    Use high-level professional language suitable for a client demonstration.
    Make it look like a unified 'Security Intelligence Dashboard'.
    """

    api_key = os.getenv('GEMINI_API_KEY')
    if not api_key:
        print("Missing GEMINI_API_KEY environment variable.")
        sys.exit(1)

    print("Sending data to AI for analysis...")
    ai_report = get_gemini_response(prompt, api_key)

    # Write the report to a markdown file and GITHUB_STEP_SUMMARY
    summary_file = os.getenv('GITHUB_STEP_SUMMARY')
    if summary_file:
        with open(summary_file, 'a', encoding='utf-8') as f:
            f.write("\n\n---\n")
            f.write("## 🤖 AI Security & Quality Intelligence Report\n")
            f.write(ai_report)
            f.write("\n\n---")
    
    with open('AI_SECURITY_REPORT.md', 'w', encoding='utf-8') as f:
        f.write(ai_report)

    print("AI Analysis Complete. Report generated in GITHUB_STEP_SUMMARY.")

if __name__ == "__main__":
    main()
