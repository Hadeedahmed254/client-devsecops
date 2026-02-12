"""
Test Data Generator for S3 Security Reports

This script generates realistic historical security scan data for demo purposes.
It creates 30 days of fake reports with realistic vulnerability patterns and trends.

⚠️ FOR DEMO ONLY - Do not include in production deployment
"""

import json
import boto3
import random
from datetime import datetime, timedelta
import os

# Realistic CVE database
CRITICAL_CVES = [
    {"id": "CVE-2023-44487", "pkg": "netty", "title": "HTTP/2 Rapid Reset Attack", "fix": "4.1.100.Final"},
    {"id": "CVE-2023-20883", "pkg": "spring-boot", "title": "Spring Boot Security Bypass", "fix": "3.1.5"},
    {"id": "CVE-2021-44228", "pkg": "log4j-core", "title": "Log4Shell RCE", "fix": "2.17.1"},
    {"id": "CVE-2023-42503", "pkg": "commons-io", "title": "Path Traversal", "fix": "2.14.0"},
]

HIGH_CVES = [
    {"id": "CVE-2023-35116", "pkg": "jackson-databind", "title": "Deserialization Issue", "fix": "2.15.3"},
    {"id": "CVE-2023-34462", "pkg": "netty-handler", "title": "SSL/TLS Vulnerability", "fix": "4.1.96.Final"},
    {"id": "CVE-2023-20862", "pkg": "spring-expression", "title": "SpEL Injection", "fix": "6.0.13"},
]

MEDIUM_CVES = [
    {"id": "CVE-2023-33201", "pkg": "bouncy-castle", "title": "Weak Encryption", "fix": "1.76"},
    {"id": "CVE-2023-34035", "pkg": "spring-security", "title": "Authorization Bypass", "fix": "6.1.5"},
]

SECRET_TYPES = [
    {"rule": "aws-access-token", "desc": "AWS Access Key", "file": "src/main/resources/application.yml"},
    {"rule": "generic-api-key", "desc": "Generic API Key", "file": "src/main/java/com/bank/config/ApiConfig.java"},
    {"rule": "slack-webhook", "desc": "Slack Webhook URL", "file": "src/main/resources/config-prod.yml"},
    {"rule": "jwt-secret", "desc": "JWT Secret Key", "file": "src/main/java/com/bank/security/JwtUtil.java"},
]

def generate_trivy_report(day_number, base_vulns=50):
    """Generate realistic Trivy vulnerability report"""
    
    # Simulate trend: vulnerabilities increase over time
    trend_factor = 1 + (day_number / 100)  # Gradual increase
    vuln_count = int(base_vulns * trend_factor)
    
    # Add some randomness
    vuln_count += random.randint(-3, 5)
    
    vulnerabilities = []
    
    # Always include persistent CRITICAL (log4j) - shows it's not being fixed
    vulnerabilities.append({
        "VulnerabilityID": "CVE-2021-44228",
        "PkgName": "log4j-core",
        "InstalledVersion": "2.14.1",
        "FixedVersion": "2.17.1",
        "Severity": "CRITICAL",
        "Title": "Apache Log4j2 Remote Code Execution (Log4Shell)",
        "Description": "Apache Log4j2 <=2.14.1 JNDI features used in configuration, log messages, and parameters do not protect against attacker controlled LDAP and other JNDI related endpoints.",
        "PrimaryURL": "https://nvd.nist.gov/vuln/detail/CVE-2021-44228"
    })
    
    # Add other CRITICAL vulnerabilities (increasing over time)
    critical_count = min(3 + (day_number // 10), 8)
    for i in range(critical_count):
        cve = random.choice(CRITICAL_CVES)
        vulnerabilities.append({
            "VulnerabilityID": cve["id"],
            "PkgName": cve["pkg"],
            "InstalledVersion": "1.0.0",
            "FixedVersion": cve["fix"],
            "Severity": "CRITICAL",
            "Title": cve["title"],
            "Description": f"Critical security vulnerability in {cve['pkg']}",
            "PrimaryURL": f"https://nvd.nist.gov/vuln/detail/{cve['id']}"
        })
    
    # Add HIGH vulnerabilities
    high_count = int(vuln_count * 0.3)
    for i in range(high_count):
        cve = random.choice(HIGH_CVES)
        vulnerabilities.append({
            "VulnerabilityID": cve["id"],
            "PkgName": cve["pkg"],
            "InstalledVersion": "2.0.0",
            "FixedVersion": cve["fix"],
            "Severity": "HIGH",
            "Title": cve["title"],
            "Description": f"High severity issue in {cve['pkg']}",
            "PrimaryURL": f"https://nvd.nist.gov/vuln/detail/{cve['id']}"
        })
    
    # Add MEDIUM and LOW
    medium_count = int(vuln_count * 0.4)
    low_count = vuln_count - len(vulnerabilities) - medium_count
    
    for i in range(medium_count):
        cve = random.choice(MEDIUM_CVES)
        vulnerabilities.append({
            "VulnerabilityID": cve["id"],
            "PkgName": cve["pkg"],
            "InstalledVersion": "3.0.0",
            "FixedVersion": cve["fix"],
            "Severity": "MEDIUM",
            "Title": cve["title"],
            "Description": f"Medium severity issue",
            "PrimaryURL": f"https://nvd.nist.gov/vuln/detail/{cve['id']}"
        })
    
    for i in range(max(0, low_count)):
        vulnerabilities.append({
            "VulnerabilityID": f"CVE-2023-{random.randint(10000, 99999)}",
            "PkgName": random.choice(["commons-lang", "guava", "slf4j"]),
            "InstalledVersion": "1.0.0",
            "FixedVersion": "1.1.0",
            "Severity": "LOW",
            "Title": "Low severity issue",
            "Description": "Low priority security issue",
            "PrimaryURL": "https://nvd.nist.gov/"
        })
    
    return {
        "SchemaVersion": "2.0.0",
        "ArtifactName": "pom.xml",
        "ArtifactType": "filesystem",
        "Results": [{
            "Target": "pom.xml",
            "Class": "lang-pkgs",
            "Type": "jar",
            "Vulnerabilities": vulnerabilities
        }]
    }

def generate_gitleaks_report(day_number):
    """Generate Gitleaks secret detection report"""
    
    # Secrets increase over time (developers keep committing them)
    if day_number < 10:
        secret_count = random.randint(0, 2)
    elif day_number < 20:
        secret_count = random.randint(2, 4)
    else:
        secret_count = random.randint(4, 7)
    
    secrets = []
    for i in range(secret_count):
        secret_type = random.choice(SECRET_TYPES)
        secrets.append({
            "Description": secret_type["desc"],
            "StartLine": random.randint(10, 200),
            "EndLine": random.randint(10, 200),
            "StartColumn": 1,
            "EndColumn": 50,
            "Match": "REDACTED",
            "Secret": "REDACTED",
            "File": secret_type["file"],
            "Commit": f"abc{random.randint(1000, 9999)}def",
            "Entropy": round(random.uniform(3.5, 5.5), 2),
            "Author": random.choice(["john.doe", "jane.smith", "dev.user"]),
            "Email": "developer@example.com",
            "Date": (datetime.now() - timedelta(days=day_number)).isoformat(),
            "Message": "feat: add new feature",
            "Tags": [],
            "RuleID": secret_type["rule"],
            "Fingerprint": f"fp{random.randint(100000, 999999)}"
        })
    
    return secrets

def generate_snyk_report(day_number):
    """Generate Snyk dependency scan report"""
    
    # Snyk finds fewer vulnerabilities than Trivy (focuses on dependencies)
    base_vulns = 15
    trend_factor = 1 + (day_number / 80)  # Slower increase than Trivy
    vuln_count = int(base_vulns * trend_factor) + random.randint(-2, 3)
    
    vulnerabilities = []
    
    for i in range(vuln_count):
        severity = random.choices(
            ['critical', 'high', 'medium', 'low'],
            weights=[0.1, 0.3, 0.4, 0.2]
        )[0]
        
        pkg = random.choice(['lodash', 'axios', 'express', 'moment', 'react'])
        
        vulnerabilities.append({
            "id": f"SNYK-JS-{pkg.upper()}-{random.randint(100000, 999999)}",
            "title": f"{severity.capitalize()} severity vulnerability in {pkg}",
            "severity": severity,
            "packageName": pkg,
            "version": f"{random.randint(1,5)}.{random.randint(0,20)}.{random.randint(0,10)}",
            "fixedIn": [f"{random.randint(2,6)}.{random.randint(0,20)}.{random.randint(0,10)}"],
            "from": [pkg],
            "upgradePath": [pkg],
            "isPatchable": random.choice([True, False]),
            "isUpgradable": True,
            "cvssScore": round(random.uniform(4.0, 9.5), 1),
            "publicationTime": (datetime.now() - timedelta(days=random.randint(30, 365))).isoformat(),
            "disclosureTime": (datetime.now() - timedelta(days=random.randint(40, 400))).isoformat()
        })
    
    return {
        "vulnerabilities": vulnerabilities,
        "ok": len(vulnerabilities) == 0,
        "dependencyCount": 150 + day_number,
        "packageManager": "npm"
    }


def generate_metadata(day_number, date):
    """Generate metadata file"""
    date_path = date.strftime('%Y/%m/%d')
    return {
        "run_id": f"{day_number:03d}",
        "commit_sha": f"abc{random.randint(100000, 999999)}def",
        "branch": "main",
        "timestamp": date.isoformat() + "Z",
        "workflow": "CICD Pipeline",
        "actor": "github-actions",
        "event": "workflow_dispatch",
        "generated": True,
        "reports": {
            "trivy": f"trivy/{date_path}/run-{day_number:03d}/trivy-report.json",
            "snyk": f"snyk/{date_path}/run-{day_number:03d}/snyk-report.json",
            "gitleaks": f"gitleaks/{date_path}/run-{day_number:03d}/gitleaks-report.json"
        }
    }

def upload_to_s3(bucket_name, date, run_number, reports):
    """Upload generated reports to S3 in structured folders"""
    s3 = boto3.client('s3')
    date_path = date.strftime('%Y/%m/%d')
    
    # Map report types to their dedicated subfolders
    type_map = {
        "trivy-report.json": "trivy",
        "gitleaks-report.json": "gitleaks",
        "snyk-report.json": "snyk",
        "metadata.json": "metadata"
    }
    
    for filename, content in reports.items():
        type_folder = type_map.get(filename, "other")
        s3_key = f"{type_folder}/{date_path}/run-{run_number:03d}/{filename}"
        
        try:
            s3.put_object(
                Bucket=bucket_name,
                Key=s3_key,
                Body=json.dumps(content, indent=2),
                ContentType='application/json'
            )
        except Exception as e:
            print(f"⚠️ Failed to upload {filename}: {e}")

def main():
    print("🎭 Test Data Generator - Creating 30 Days of Demo Data")
    print("=" * 60)
    
    # Get S3 bucket name
    bucket_name = os.getenv('S3_SECURITY_REPORTS_BUCKET')
    if not bucket_name:
        print("❌ Error: S3_SECURITY_REPORTS_BUCKET environment variable not set")
        print("   Set it to your S3 bucket name from Terraform output")
        return
    
    print(f"📦 Target S3 Bucket: {bucket_name}")
    print(f"📅 Generating 30 days of historical data...\n")
    
    # Generate data for last 30 days
    start_date = datetime.now() - timedelta(days=30)
    
    for day in range(30):
        current_date = start_date + timedelta(days=day)
        run_number = day + 1
        
        print(f"Day {run_number:2d} ({current_date.strftime('%Y-%m-%d')}): ", end='')
        
        # Generate reports
        trivy_report = generate_trivy_report(day)
        gitleaks_report = generate_gitleaks_report(day)
        snyk_report = generate_snyk_report(day)
        metadata = generate_metadata(run_number, current_date)
        
        reports = {
            "trivy-report.json": trivy_report,
            "gitleaks-report.json": gitleaks_report,
            "snyk-report.json": snyk_report,
            "metadata.json": metadata
        }
        
        # Upload to S3
        upload_to_s3(bucket_name, current_date, run_number, reports)
        
        # Show summary
        vuln_count = len(trivy_report['Results'][0]['Vulnerabilities'])
        secret_count = len(gitleaks_report)
        print(f"✅ {vuln_count} vulns, {secret_count} secrets")
    
    print("\n" + "=" * 60)
    print("🎉 Test data generation complete!")
    print("\nNext steps:")
    print("1. Verify in S3: aws s3 ls s3://{bucket_name}/")
    print("2. Repair Athena partitions:")
    print("   MSCK REPAIR TABLE security_analytics.trivy_scans;")
    print("   MSCK REPAIR TABLE security_analytics.gitleaks_scans;")
    print("3. Run Athena queries to see trends")
    print("4. Set up QuickSight dashboards")
    print("\n⚠️ Remember: This is DEMO DATA for presentation purposes only!")

if __name__ == "__main__":
    main()
