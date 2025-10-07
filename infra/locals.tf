# Common tags for all resources
locals {
  common_tags = {
    Environment  = var.environment
    Project      = "contact-form-webapp"
    ManagedBy    = "terraform"
    CostCenter   = "development"
    Owner        = "devops-team"
    BusinessUnit = "engineering"
    Application  = "contact-form"

    # Operational tags
    Purpose        = "web-application"
    Sustainability = "enabled"
    AutoShutdown   = var.environment != "production" ? "enabled" : "disabled"
    BackupRequired = var.environment == "production" ? "yes" : "no"

    # Compliance tags
    DataClass  = "internal"
    Compliance = "standard"
  }
}
