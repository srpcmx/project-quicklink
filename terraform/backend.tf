# This block tells Terraform to use an S3 remote backend
terraform {
  backend "s3" {
    bucket         = "quicklink-terraform-state-bucket"
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "quicklink-terraform-state-lock"
  }
}
