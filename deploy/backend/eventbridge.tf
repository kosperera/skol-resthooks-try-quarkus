module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws"

  # create_bus = false
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

  targets = {
    order_notifications = [
      # Send to a Queue and a Pipe will pick it up and
      # Send it to the Lambda function (Backend Webhook Endpoint).
      {
        name            = "send-to-lambdawebapi-queue"
        arn             = module.sqs_lambdawebapi.queue_arn
        dead_letter_arn = module.sqs_lambdawebapi.dead_letter_queue_arn
        target_id       = "send-to-lambdawebapi-queue"
      },
      # Skip the Queues, and send to a Backend Webhook Endpoint.
      {
        name            = "send-to-backend-webapi"
        destination     = "backend_webapi"
        attach_role_arn = true
      }
    ]
  }

  attach_sqs_policy = true
  sqs_target_arns = [
    module.sqs_lambdawebapi.queue_arn,
    module.sqs_lambdawebapi.dead_letter_queue_arn
  ]

  # Pipes are required to dequeue and then 
  # send to a Lambda Web API (HTTP Endpoint).

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

  # Skip the Queues, just send directly
  # to a Backend Webhook Endpoint.

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

# Large Messages are send to an S3 Bucket and 
# EventBridge will forward that to a Queue.

module "default_bridge" {
  source = "terraform-aws-modules/eventbridge/aws"

  create_bus = false

  rules = {
    large_notifications = {
      description = "Captures all created order notifications (bulk or large payloads)",
      event_pattern = jsonencode({
        "source" : ["aws.s3"],
        "detail-type" : ["Object Created"]
        "detail" : { "bucket" : { "name" : [module.s3_bucket.s3_bucket_id] } }
      })
      state = "ENABLED"
    }
  }

  # Send to a Queue and a Lambda will pick it up.
  targets = {
    large_notifications = [
      # Send to a Queue and a Pipe will pick it up and
      # Send it to the Lambda function (Backend Webhook Endpoint).
      {
        name            = "send-to-lambdawebapi-queue"
        arn             = module.sqs_lambdawebapi.queue_arn
        dead_letter_arn = module.sqs_lambdawebapi.dead_letter_queue_arn
        target_id       = "send-to-lambdawebapi-queue"
      }
    ]
  }
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "sb-s3-kitchensync-receiver-01"

  attach_policy = true
  policy = data.aws_iam_policy_document.bucket.json
}

module "s3_notify" {
  source = "terraform-aws-modules/s3-bucket/aws//modules/notification"

  bucket      = module.s3_bucket.s3_bucket_id
  eventbridge = true
}
