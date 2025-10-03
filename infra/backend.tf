terraform {
  backend "s3" {
    bucket         = "project3-terraform-state-lerthy-2025"
    key            = "project3/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
