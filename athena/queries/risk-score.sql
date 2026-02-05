-- ========================================
-- Security Risk Score Calculation
-- ========================================
-- Calculates a risk score (0-100) based on:
-- - CRITICAL: 10 points each
-- - HIGH: 5 points each
-- - MEDIUM: 2 points each
-- - LOW: 0.5 points each
-- - Secrets: 15 points each
-- ========================================

WITH vulnerability_scores AS (
  SELECT 
    CONCAT(year, '-', month, '-', day) as scan_date,
    SUM(CASE WHEN vuln.Severity = 'CRITICAL' THEN 10 ELSE 0 END) as critical_score,
    SUM(CASE WHEN vuln.Severity = 'HIGH' THEN 5 ELSE 0 END) as high_score,
    SUM(CASE WHEN vuln.Severity = 'MEDIUM' THEN 2 ELSE 0 END) as medium_score,
    SUM(CASE WHEN vuln.Severity = 'LOW' THEN 0.5 ELSE 0 END) as low_score,
    COUNT(*) as total_vulns
  FROM security_analytics.trivy_scans
  CROSS JOIN UNNEST(Results) AS t(result)
  CROSS JOIN UNNEST(result.Vulnerabilities) AS v(vuln)
  GROUP BY year, month, day
),
secret_scores AS (
  SELECT 
    CONCAT(year, '-', month, '-', day) as scan_date,
    COUNT(*) * 15 as secret_score,
    COUNT(*) as total_secrets
  FROM security_analytics.gitleaks_scans
  GROUP BY year, month, day
)
SELECT 
  COALESCE(v.scan_date, s.scan_date) as scan_date,
  COALESCE(v.critical_score, 0) + 
  COALESCE(v.high_score, 0) + 
  COALESCE(v.medium_score, 0) + 
  COALESCE(v.low_score, 0) + 
  COALESCE(s.secret_score, 0) as raw_risk_score,
  LEAST(100, 
    COALESCE(v.critical_score, 0) + 
    COALESCE(v.high_score, 0) + 
    COALESCE(v.medium_score, 0) + 
    COALESCE(v.low_score, 0) + 
    COALESCE(s.secret_score, 0)
  ) as risk_score,
  CASE 
    WHEN LEAST(100, COALESCE(v.critical_score, 0) + COALESCE(v.high_score, 0) + COALESCE(v.medium_score, 0) + COALESCE(v.low_score, 0) + COALESCE(s.secret_score, 0)) <= 20 THEN 'LOW'
    WHEN LEAST(100, COALESCE(v.critical_score, 0) + COALESCE(v.high_score, 0) + COALESCE(v.medium_score, 0) + COALESCE(v.low_score, 0) + COALESCE(s.secret_score, 0)) <= 50 THEN 'MEDIUM'
    WHEN LEAST(100, COALESCE(v.critical_score, 0) + COALESCE(v.high_score, 0) + COALESCE(v.medium_score, 0) + COALESCE(v.low_score, 0) + COALESCE(s.secret_score, 0)) <= 80 THEN 'HIGH'
    ELSE 'CRITICAL'
  END as risk_level,
  COALESCE(v.total_vulns, 0) as total_vulnerabilities,
  COALESCE(s.total_secrets, 0) as total_secrets
FROM vulnerability_scores v
FULL OUTER JOIN secret_scores s ON v.scan_date = s.scan_date
ORDER BY scan_date DESC;
