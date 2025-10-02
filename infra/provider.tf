provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "standby"
  region = var.standby_region
}