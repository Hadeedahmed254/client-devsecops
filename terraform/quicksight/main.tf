
resource "aws_quicksight_data_source" "athena" {
  data_source_id = "security-analytics-source"
  name           = "SecurityAnalyticsAthena"
  type           = "ATHENA"
  aws_account_id = data.aws_caller_identity.current.account_id

  parameters {
    athena {
      work_group = "primary"
    }
  }

  permission {
    actions    = ["quicksight:DescribeDataSource", "quicksight:DescribeDataSourcePermissions", "quicksight:PassDataSource", "quicksight:UpdateDataSource", "quicksight:DeleteDataSource", "quicksight:UpdateDataSourcePermissions"]
    principal  = var.quicksight_user_arn
  }
}

resource "aws_quicksight_data_set" "trivy_trends" {
  data_set_id    = "trivy-scans-dataset"
  name           = "TrivyVulnerabilityTrends"
  aws_account_id = data.aws_caller_identity.current.account_id
  import_mode    = "DIRECT_QUERY"

  physical_table_map {
    physical_table_id = "trivy-table"
    relational_table {
      data_source_arn = aws_quicksight_data_source.athena.arn
      schema          = "security_analytics"
      name            = "trivy_scans"
      input_columns {
        name = "artifactname"
        type = "STRING"
      }
      input_columns {
        name = "year"
        type = "STRING"
      }
      input_columns {
        name = "month"
        type = "STRING"
      }
      input_columns {
        name = "day"
        type = "STRING"
      }
    }
  }

  logical_table_map {
    logical_table_id = "trivy-logical"
    alias            = "TrivyScans"
    source {
      physical_table_id = "trivy-table"
    }
    
    # We add a calculated field for the date in the logical map if needed, 
    # but for simplicity we'll keep it as the raw table for now.
  }

  permission {
    actions    = ["quicksight:DescribeDataSet", "quicksight:DescribeDataSetPermissions", "quicksight:PassDataSet", "quicksight:UpdateDataSet", "quicksight:DeleteDataSet", "quicksight:UpdateDataSetPermissions"]
    principal  = var.quicksight_user_arn
  }
}

data "aws_caller_identity" "current" {}

variable "quicksight_user_arn" {
  description = "The ARN of the QuickSight user who will own these resources"
  type        = STRING
}
