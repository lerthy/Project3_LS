terraform {
  backend "s3" {
    bucket  = "project3-terraform-state-1757872273"
    key     = "project3/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    dynamodb_table = "terraform-state-lock"
  }
}
