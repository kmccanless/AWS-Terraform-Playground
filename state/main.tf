provider "aws" {
  region = var.region
  profile = var.profile
}
terraform {
  backend "s3" {
    bucket         = "rds-test-terraform-state"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "rds-test-terraform-locks"
    encrypt        = true
    profile        = "test-acct-1-admin"
  }
}
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project}-terraform-state"
  # Enable versioning so we can see the full revision history of our
  # state files
  versioning {
    enabled = true
  }
  # Enable server-side encryption by default
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}