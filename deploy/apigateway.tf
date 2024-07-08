module "apigateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  name          = "apig-v2-kitchensync"
  description   = "My apig-v2-kitchensync HTTP API Gateway"
  protocol_type = "HTTP"

  create_domain_name = false
  authorizers = {
    cognito = {
      name             = "cognito"
      authorizer_type  = "JWT"
      identity_sources = ["$request.header.Authorization"]
      jwt_configuration = {
        audience = [aws_cognito_user_pool_client.client.id]
        issuer   = "https://${aws_cognito_user_pool.pool.endpoint}"
      }
    }
  }

  routes = {
    "POST /v1/messaging/publish" = {

      authorizer_key       = "cognito"
      authorization_type   = "JWT"
      authorization_scopes = aws_cognito_resource_server.resource.scope_identifiers

      integration = {
        type            = "AWS_PROXY"
        subtype         = "EventBridge-PutEvents"
        credentials_arn = module.apigateway_put_events_to_eventbridge_role.iam_role_arn

        request_parameters = {
          EventBusName = module.eventbridge.eventbridge_bus_name,
          Source       = "$request.header.X-SOURCE",
          DetailType   = "$request.header.X-EVENT-KIND",
          Detail       = "$request.body",
          # Detail = jsonencode({
          #   Metadata = jsonencode({
          #     SourceCorrelationId = "$request.header.X-CORRELATION-ID",
          #     CorrelationId = "$context.requestId",
          #     EventSource = "$request.header.X-SOURCE",
          #     EventKind = "$request.header.X-EVENT-KIND",
          #     Environment = "$request.header.X-ENVIRONMENT",
          #     Timestamp = "$context.requestTimeEpoch"
          #   }),
          #   Data = "$request.body"
          # }),
          Time = "$context.requestTimeEpoch"
        }

        payload_format_version = "1.0"
      }
    }
  }
}

module "apigateway_put_events_to_eventbridge_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"

  create_role       = true
  role_name         = "apigateway-put-events-to-eventbridge"
  role_requires_mfa = false

  trusted_role_services = ["apigateway.amazonaws.com"]

  custom_role_policy_arns = [
    module.apigateway_put_events_to_eventbridge_policy.arn
  ]
}

module "apigateway_put_events_to_eventbridge_policy" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name        = "apigateway-put-events-to-eventbridge"
  description = "Allow PutEvents to EventBridge"

  policy = data.aws_iam_policy_document.apigateway_put_events_to_eventbridge_policy.json
}

data "aws_iam_policy_document" "apigateway_put_events_to_eventbridge_policy" {
  statement {
    sid       = "AllowPutEvents"
    actions   = ["events:PutEvents"]
    resources = [module.eventbridge.eventbridge_bus_arn]
  }

  depends_on = [module.eventbridge]
}
