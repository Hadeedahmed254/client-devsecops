-- ========================================
-- Secret Leakage Trend Analysis
-- ========================================
-- Tracks secret detection patterns over time
-- Identifies if developers are improving or still committing secrets
-- ========================================

-- Daily secret count
SELECT 
  CONCAT(year, '-', month, '-', day) as scan_date,
  COUNT(*) as secrets_found,
  COUNT(DISTINCT File) as affected_files,
  COUNT(DISTINCT RuleID) as rule_types
FROM security_analytics.gitleaks_scans
WHERE 
  CAST(CONCAT(year, month, day) AS INTEGER) >= CAST(date_format(current_date - interval '30' day, '%Y%m%d') AS INTEGER)
GROUP BY year, month, day
ORDER BY scan_date DESC;


-- Secret types breakdown
SELECT 
  CONCAT(year, '-', month, '-', day) as scan_date,
  RuleID as secret_type,
  COUNT(*) as count,
  ARRAY_AGG(DISTINCT File) as affected_files
FROM security_analytics.gitleaks_scans
WHERE 
  CAST(CONCAT(year, month, day) AS INTEGER) >= CAST(date_format(current_date - interval '30' day, '%Y%m%d') AS INTEGER)
GROUP BY year, month, day, RuleID
ORDER BY scan_date DESC, count DESC;


-- Files with most secrets
SELECT 
  File,
  COUNT(*) as secret_count,
  ARRAY_AGG(DISTINCT RuleID) as secret_types,
  MIN(CONCAT(year, '-', month, '-', day)) as first_detected,
  MAX(CONCAT(year, '-', month, '-', day)) as last_detected
FROM security_analytics.gitleaks_scans
GROUP BY File
HAVING COUNT(*) > 1
ORDER BY secret_count DESC
LIMIT 20;
