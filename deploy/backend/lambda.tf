module "lambda_receiver" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "sb-fn-${basename(path.cwd)}"
  description   = "Quarkus greets to whomever ..."
  handler       = "io.quarkus.amazon.lambda.runtime.QuarkusStreamHandler"
  runtime       = "java21"
  architectures = ["arm64"]
  publish       = true

  create_package = false

  # HINT: Run ./mvnw clean install to build and package.
  local_existing_package = "../../target/function.zip"

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.apigateway.api_execution_arn}/*/*"
    }
  }

  environment_variables = {
    BUCKET_NAME = module.s3_bucket.s3_bucket_id
  }
  create_role = true
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "sb-s3-kitchensync-receiver-01"

  attach_policy = true
  policy        = data.aws_iam_policy_document.bucket.json
}

module "s3_notify" {
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
      values   = [module.lambda_receiver.lambda_role_arn]
    }
  }
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid = "RestrictBucketAccessToIAMRole"

    principals {
      type        = "AWS"
      identifiers = [module.lambda_receiver.lambda_role_arn]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${module.s3_bucket.s3_bucket_arn}/*",
    ]
  }
}
