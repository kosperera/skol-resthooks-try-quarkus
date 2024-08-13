module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "sb-s3-ksync-events-01"

  attach_policy = true
  policy        = data.aws_iam_policy_document.bucket.json
}

# Enables bucket activities.
module "s3_events" {
  source = "terraform-aws-modules/s3-bucket/aws//modules/notification"

  bucket      = module.s3_bucket.s3_bucket_id
  eventbridge = true
}

data "aws_iam_policy_document" "endpoint" {
  statement {
    sid = "RestrictBucketAccessToIAMRole"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${module.s3_bucket.s3_bucket_arn}/*",
    ]

    # See https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html#edit-vpc-endpoint-policy-s3
    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [module.func_http_v2_event.lambda_role_arn]
    }
  }
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid = "RestrictBucketAccessToIAMRole"

    principals {
      type        = "AWS"
      identifiers = [module.func_http_v2_event.lambda_role_arn]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${module.s3_bucket.s3_bucket_arn}/*",
    ]
  }
}
