module "backend-func" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "sb-fn-${basename(path.cwd)}"
  description = "Quarkus greets to whomever ..."
  handler = "io.quarkus.amazon.lambda.runtime.QuarkusStreamHandler"
  runtime = "java21"
  architectures = ["arm64"]
  publish = true

  create_package = false
  local_existing_package = "../../target/function.zip"

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
        service = "apigateway"
        source_arn = "${module.apigateway.api_execution_arn}/*/*"
    }
  }
}