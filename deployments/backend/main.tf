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
    key            = "sync/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/tf_bucket_key"
    dynamodb_table = "tf_state_lock"
  }
}

provider "aws" {
  region = "us-east-1"

  # Make it faster by skipping something
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true

  default_tags {
    tags = {
      Product = "Skol"
      Stack   = "KitchenSync"
    }
  }
}
