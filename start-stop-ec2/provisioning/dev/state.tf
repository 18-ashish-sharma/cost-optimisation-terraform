terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    region         = "ap-south-1"
    bucket         = "<bucket-name>"
    key            = "<key>/terraform.tfstate"
    encrypt        = "true"
  }
}