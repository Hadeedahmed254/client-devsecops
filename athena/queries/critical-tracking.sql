-- ========================================
-- Critical Vulnerability Tracking
-- ========================================
-- Tracks specific CRITICAL vulnerabilities over time
-- Shows which issues persist and need urgent attention
-- ========================================

SELECT 
  CONCAT(year, '-', month, '-', day) as scan_date,
  vuln.VulnerabilityID,
  vuln.PkgName,
  vuln.InstalledVersion,
  vuln.FixedVersion,
  vuln.Title,
  vuln.Severity,
  vuln.PrimaryURL
FROM security_analytics.trivy_scans
CROSS JOIN UNNEST(Results) AS t(result)
CROSS JOIN UNNEST(result.Vulnerabilities) AS v(vuln)
WHERE vuln.Severity = 'CRITICAL'
  AND CAST(CONCAT(year, month, day) AS INTEGER) >= CAST(date_format(current_date - interval '30' day, '%Y%m%d') AS INTEGER)
ORDER BY scan_date DESC, vuln.VulnerabilityID;


-- Count how many times each CRITICAL vulnerability appears
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
HAVING COUNT(DISTINCT CONCAT(year, month, day)) > 1  -- Only show persistent issues
ORDER BY days_present DESC, vuln.VulnerabilityID;
