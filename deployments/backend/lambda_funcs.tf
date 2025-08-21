module "func_http_v2_event" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "sb-fn-ksync-eventtos3-01"
  description   = "Accepts HTTP requests via API Gateway and writes the request body into an s3 bucket instead of a queue."

  handler = "io.quarkus.amazon.lambda.runtime.QuarkusStreamHandler"
  # Running native.
  # runtime       = "java21"
  runtime       = "provided.al2023"
  architectures = ["arm64"]

  timeout = 7 # Max: 900 (15 mins)
  publish = true

  create_package = false

  # HINT: Run ./mvnw clean install package -Dnative -Dquarkus.native.container-build=true
  #       to build and package.
  local_existing_package = "../../src/kitchen_sync/events/target/function.zip"

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.http_api.api_execution_arn}/*/*"
    }
  }

  environment_variables = {
    DESTINATION_BUCKET_NAME = module.s3_bucket.s3_bucket_id
    DISABLE_SIGNAL_HANDLERS = true
  }

  create_role = true
}

module "func_enrich_event_v2" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "sb-fn-ksync-ev2enrich-01"
  description   = "Accepts HTTP requests via API Gateway and writes the request body into an s3 bucket instead of a queue."

  handler = "bootstrap"
  # Running native.
  # runtime       = "java21"
  runtime       = "provided.al2023"
  architectures = ["arm64"]

  timeout = 7 # Max: 900 (15 mins)
  publish = true

  create_package = false

  # HINT: Run ./mvnw clean install package -Dnative -Dquarkus.native.container-build=true
  #       to build and package.
  local_existing_package = "../../src/internal/events/enrich/target/function.zip"

  environment_variables = {
    DISABLE_SIGNAL_HANDLERS = true
  }

  create_role = true
}
