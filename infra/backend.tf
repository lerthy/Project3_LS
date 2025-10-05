terraform {
  backend "s3" {
    bucket         = "terraform-state-project4-sb"
    key            = "project4/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
