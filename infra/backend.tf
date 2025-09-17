terraform {
  backend "s3" {
    bucket  = "project3-terraform-state-1758100191"
    key     = "project3/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    # dynamodb_table = "terraform-state-lock"  # Commented out for now
  }
}
