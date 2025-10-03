# Data source to fetch database credentials from Secrets Manager
data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = "project3/db-credentials"
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)
}