terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.3.0"
  
  backend "s3" {
    bucket = "project3-terraform-state-fb49b77e"
    key    = "infrastructure/terraform.tfstate"
    region = "eu-north-1"
  }
}

provider "aws" {
  region = var.aws_region 
}
