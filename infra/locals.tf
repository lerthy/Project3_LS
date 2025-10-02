# Comprehensive cost allocation and tracking tags
locals {
  # Base cost allocation tags
  cost_allocation_tags = {
    Environment   = var.environment
    Project      = "contact-form"
    Application  = "web-application"
    CostCenter   = var.cost_center
    Owner        = var.owner
    Team         = var.team
    ManagedBy    = "terraform"
    
    # Cost optimization flags
    CostOptimized    = "true"
    AutoShutdown     = var.environment != "production" ? "enabled" : "disabled"
    BackupRetention  = var.environment == "production" ? "7-days" : "1-day"
    
    # Financial tracking
    BillingProject   = "devops-cicd-project"
    Department       = "engineering"
    
    # Operational tags
    Criticality      = var.environment == "production" ? "high" : "medium"
    DataClassification = "internal"
    
    # Resource lifecycle
    CreatedDate      = formatdate("YYYY-MM-DD", timestamp())
    LastModified     = formatdate("YYYY-MM-DD", timestamp())
  }
  
  # Merge with existing common tags
  common_tags = merge(local.cost_allocation_tags, var.additional_tags)
}