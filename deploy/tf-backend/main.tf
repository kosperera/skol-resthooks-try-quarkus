terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  # Uncomment to move to remote backend.
  # See https://github.com/kosperera/devlogs/issues/117
  backend "s3" {
    bucket         = "tf-state-skol"
    key            = "state/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/tf_bucket_key"
    dynamodb_table = "tf_state_lock"
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Product = "Skol"
      Stack   = "Terraform.State"
    }
  }
}
