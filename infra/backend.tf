terraform {
  backend "s3" {
    bucket         = "terraform-state-project3-eunorth1-20251004-lerdisalihi"
    key            = "project3/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
