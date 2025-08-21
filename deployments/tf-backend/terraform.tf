# Source https://github.com/terraform-aws-modules/terraform-aws-kms
module "terraform_bucket_key" {
  source = "terraform-aws-modules/kms/aws"

  description             = "This key is used to encrypt bucket objects."
  deletion_window_in_days = 10
  enable_key_rotation     = true

  aliases_use_name_prefix = false
  computed_aliases = {
    ex = {
      name = "tf_bucket_key"
    }
  }
}

# Source https://github.com/terraform-aws-modules/terraform-aws-s3-bucket
module "terraform_state" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "tf-state-skol"
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = module.terraform_bucket_key.key_arn
      }
    }
  }

  versioning = {
    enabled = true
  }
}

# Source https://github.com/terraform-aws-modules/terraform-aws-dynamodb-table
module "dynamodb_lock_table" {
  source = "terraform-aws-modules/dynamodb-table/aws"
  name   = "tf_state_lock"

  # For billing mode: On-demand
  # read_capacity = 20
  # write_capacity = 20

  hash_key = "LockID"

  attributes = [{
    name = "LockID"
    type = "S"
  }]
}
