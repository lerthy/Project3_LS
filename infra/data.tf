# Data source to fetch database credentials from Secrets Manager
# Reference the secret version created in secrets.tf
locals {
  db_creds = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string)
}