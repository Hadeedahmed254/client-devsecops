-- ========================================
-- Security Analytics Database Setup
-- ========================================
-- This script creates the Athena database and tables
-- for querying security scan reports from S3
--
-- Usage: Run this in AWS Athena console after S3 bucket is created
-- Replace {BUCKET_NAME} with your actual S3 bucket name
-- ========================================

-- Create database
CREATE DATABASE IF NOT EXISTS security_analytics
COMMENT 'Security scan reports from CI/CD pipeline'
LOCATION 's3://bankapp-security-reports-211125523455/';

-- ========================================
-- Trivy Vulnerability Scans Table
-- ========================================
CREATE EXTERNAL TABLE IF NOT EXISTS security_analytics.trivy_scans (
  SchemaVersion STRING,
  ArtifactName STRING,
  ArtifactType STRING,
  Metadata STRUCT<
    ImageID: STRING,
    DiffIDs: ARRAY<STRING>,
    RepoTags: ARRAY<STRING>,
    RepoDigests: ARRAY<STRING>
  >,
  Results ARRAY<STRUCT<
    Target: STRING,
    Class: STRING,
    Type: STRING,
    Vulnerabilities: ARRAY<STRUCT<
      VulnerabilityID: STRING,
      PkgName: STRING,
      InstalledVersion: STRING,
      FixedVersion: STRING,
      Severity: STRING,
      Title: STRING,
      Description: STRING,
      PrimaryURL: STRING,
      PublishedDate: STRING,
      LastModifiedDate: STRING
    >>
  >>
)
PARTITIONED BY (
  year STRING,
  month STRING,
  day STRING
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
WITH SERDEPROPERTIES (
  'ignore.malformed.json' = 'true'
)
LOCATION 's3://bankapp-security-reports-211125523455/trivy/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.year.type' = 'integer',
  'projection.year.range' = '2024,2030',
  'projection.month.type' = 'integer',
  'projection.month.range' = '01,12',
  'projection.month.digits' = '2',
  'projection.day.type' = 'integer',
  'projection.day.range' = '01,31',
  'projection.day.digits' = '2',
  'storage.location.template' = 's3://bankapp-security-reports-211125523455/trivy/${year}/${month}/${day}',
  'recursive.directories' = 'true'
);

-- ========================================
-- Gitleaks Secret Scans Table
-- ========================================
CREATE EXTERNAL TABLE IF NOT EXISTS security_analytics.gitleaks_scans (
  Description STRING,
  StartLine INT,
  EndLine INT,
  StartColumn INT,
  EndColumn INT,
  Match STRING,
  Secret STRING,
  File STRING,
  Commit STRING,
  Entropy DOUBLE,
  Author STRING,
  Email STRING,
  Date STRING,
  Message STRING,
  Tags ARRAY<STRING>,
  RuleID STRING,
  Fingerprint STRING
)
PARTITIONED BY (
  year STRING,
  month STRING,
  day STRING
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
WITH SERDEPROPERTIES (
  'ignore.malformed.json' = 'true'
)
LOCATION 's3://bankapp-security-reports-211125523455/gitleaks/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.year.type' = 'integer',
  'projection.year.range' = '2024,2030',
  'projection.month.type' = 'integer',
  'projection.month.range' = '01,12',
  'projection.month.digits' = '2',
  'projection.day.type' = 'integer',
  'projection.day.range' = '01,31',
  'projection.day.digits' = '2',
  'storage.location.template' = 's3://bankapp-security-reports-211125523455/gitleaks/${year}/${month}/${day}',
  'recursive.directories' = 'true'
);

-- ========================================
-- Snyk Vulnerability Scans Table
-- ========================================
CREATE EXTERNAL TABLE IF NOT EXISTS security_analytics.snyk_scans (
  vulnerabilities ARRAY<STRUCT<
    id: STRING,
    title: STRING,
    severity: STRING,
    packageName: STRING,
    version: STRING,
    fixedIn: ARRAY<STRING>,
    `from`: ARRAY<STRING>,
    upgradePath: ARRAY<STRING>,
    isPatchable: BOOLEAN,
    isUpgradable: BOOLEAN,
    cvssScore: DOUBLE,
    publicationTime: STRING,
    disclosureTime: STRING
  >>,
  ok: BOOLEAN,
  dependencyCount: INT,
  packageManager: STRING
)
PARTITIONED BY (
  year STRING,
  month STRING,
  day STRING
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
WITH SERDEPROPERTIES (
  'ignore.malformed.json' = 'true'
)
LOCATION 's3://bankapp-security-reports-211125523455/snyk/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.year.type' = 'integer',
  'projection.year.range' = '2024,2030',
  'projection.month.type' = 'integer',
  'projection.month.range' = '01,12',
  'projection.month.digits' = '2',
  'projection.day.type' = 'integer',
  'projection.day.range' = '01,31',
  'projection.day.digits' = '2',
  'storage.location.template' = 's3://bankapp-security-reports-211125523455/snyk/${year}/${month}/${day}',
  'recursive.directories' = 'true'
);

-- ========================================
-- SonarQube Code Quality Table
-- ========================================
CREATE EXTERNAL TABLE IF NOT EXISTS security_analytics.sonarqube_scans (
  component STRING,
  measures ARRAY<STRUCT<
    metric: STRING,
    value: STRING,
    bestValue: BOOLEAN
  >>,
  issues ARRAY<STRUCT<
    key: STRING,
    rule: STRING,
    severity: STRING,
    component: STRING,
    line: INT,
    message: STRING,
    type: STRING,
    status: STRING
  >>
)
PARTITIONED BY (
  year STRING,
  month STRING,
  day STRING
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
WITH SERDEPROPERTIES (
  'ignore.malformed.json' = 'true'
)
LOCATION 's3://bankapp-security-reports-211125523455/sonarqube/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.year.type' = 'integer',
  'projection.year.range' = '2024,2030',
  'projection.month.type' = 'integer',
  'projection.month.range' = '01,12',
  'projection.month.digits' = '2',
  'projection.day.type' = 'integer',
  'projection.day.range' = '01,31',
  'projection.day.digits' = '2',
  'storage.location.template' = 's3://bankapp-security-reports-211125523455/sonarqube/${year}/${month}/${day}',
  'recursive.directories' = 'true'
);

-- ========================================
-- Metadata Table
-- ========================================
CREATE EXTERNAL TABLE IF NOT EXISTS security_analytics.scan_metadata (
  run_id STRING,
  commit_sha STRING,
  branch STRING,
  timestamp STRING,
  workflow STRING,
  actor STRING,
  event STRING,
  reports STRUCT<
    trivy: STRING,
    snyk: STRING,
    gitleaks: STRING,
    sonarqube: STRING
  >
)
PARTITIONED BY (
  year STRING,
  month STRING,
  day STRING
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://bankapp-security-reports-211125523455/metadata/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.year.type' = 'integer',
  'projection.year.range' = '2024,2030',
  'projection.month.type' = 'integer',
  'projection.month.range' = '01,12',
  'projection.month.digits' = '2',
  'projection.day.type' = 'integer',
  'projection.day.range' = '01,31',
  'projection.day.digits' = '2',
  'storage.location.template' = 's3://bankapp-security-reports-211125523455/metadata/${year}/${month}/${day}',
  'recursive.directories' = 'true'
);

-- ========================================
-- Repair partitions (run after first data upload)
-- ========================================
-- MSCK REPAIR TABLE security_analytics.trivy_scans;
-- MSCK REPAIR TABLE security_analytics.gitleaks_scans;
-- MSCK REPAIR TABLE security_analytics.snyk_scans;
-- MSCK REPAIR TABLE security_analytics.sonarqube_scans;
-- MSCK REPAIR TABLE security_analytics.scan_metadata;

-- ========================================
-- Verify tables created
-- ========================================
-- SHOW TABLES IN security_analytics;
