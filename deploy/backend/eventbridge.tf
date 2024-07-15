module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws"

  bus_name = "sb-evb-kitchensync-messagingbus-01"

  rules = {
    order_notifications = {
      description   = "Capture all created order notifications",
      event_pattern = jsonencode({ "detail-type" : ["Order.Notification"] })
      # is_enabled    = true is deprecated.
      # See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule#is_enabled
      state = "ENABLED"
    }
  }

  # Send to a Queue.
  targets = {
    order_notifications = [
      {
        name            = "send-to-lambdafn-queue"
        arn             = module.sqs_lambdafn.queue_arn
        dead_letter_arn = module.sqs_lambdafn.dead_letter_queue_arn
        target_id       = "send-to-lambdafn-queue"
      },
      {
        name            = "send-to-lambdawebapi-queue"
        arn             = module.sqs_lambdawebapi.queue_arn
        dead_letter_arn = module.sqs_lambdawebapi.dead_letter_queue_arn
        target_id       = "send-to-lambdawebapi-queue"
      },
      {
        name            = "send-to-backend-webapi"
        destination     = "backend_webapi"
        attach_role_arn = true
      }
    ]
  }

  attach_sqs_policy = true
  sqs_target_arns = [
    module.sqs_lambdafn.queue_arn,
    module.sqs_lambdafn.dead_letter_queue_arn,
    module.sqs_lambdawebapi.queue_arn,
    module.sqs_lambdawebapi.dead_letter_queue_arn
  ]

  # Send directly to a Backend HTTP Endpoint.
  create_api_destinations       = true
  attach_api_destination_policy = true
  api_destinations = {
    backend_webapi = {
      description                      = ""
      invocation_endpoint              = "https://${var.backend_api_host}/v1/kitchen/messaging/ingress"
      http_method                      = "POST"
      invocation_rate_limit_per_second = 2
    }
  }

  create_connections = true
  connections = {
    backend_webapi = {
      authorization_type = "API_KEY"
      auth_parameters = {
        api_key = {
          key   = "X-API-KEY"
          value = var.backend_api_key
        }
      }
    }
  }

  # Dequeue and Send to a Lambda Web API (HTTP Endpoint).
  pipes = {
    lambdawebapi = {
      source = module.sqs_lambdawebapi.queue_arn
      target = aws_cloudwatch_event_api_destination.lambdawebapi.arn

      source_parameters = {
        sqs_queue_parameters = {
          batch_size = 1
        }
      }
    }
  }
}

resource "aws_cloudwatch_event_api_destination" "lambdawebapi" {
  name                             = "lambda-webapi-destination"
  invocation_endpoint              = "https://${var.backend_api_host}/v1/pos/messaging/ingress"
  http_method                      = "POST"
  connection_arn                   = aws_cloudwatch_event_connection.lambdawebapi.arn
  invocation_rate_limit_per_second = 2
}

resource "aws_cloudwatch_event_connection" "lambdawebapi" {
  name               = "lambda-webapi-connection"
  authorization_type = "API_KEY"
  auth_parameters {
    api_key {
      key   = "X-API-KEY"
      value = var.backend_api_key
    }
  }
}
