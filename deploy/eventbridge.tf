module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws"

  bus_name = "kitchensync-bus"

  rules = {
    orders_create = {
      description   = "Capture all created orders",
      event_pattern = jsonencode({ "detail-type" : ["Order.Notification"] })
      # is_enabled    = true is deprecated.
      # See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule#is_enabled
      state = "ENABLED"
    }
  }

  # Send to a Queue.
  targets = {
    orders_create = [
      {
        name            = "send-to-pos-webhook-queue"
        arn             = module.pos_webhook_queue.queue_arn
        dead_letter_arn = module.pos_webhook_queue.dead_letter_queue_arn
        target_id       = "send-to-pos-webhook-queue"
      },
      {
        name            = "send-to-kitchen-webhook"
        destination     = "kitchen_webhook"
        attach_role_arn = true
      }
    ]
  }

  attach_sqs_policy = true
  sqs_target_arns = [
    module.pos_webhook_queue.queue_arn,
    module.pos_webhook_queue.dead_letter_queue_arn
  ]

  # Send directly to Kitchen
  create_api_destinations       = true
  attach_api_destination_policy = true
  api_destinations = {
    kitchen_webhook = {
      description                      = ""
      invocation_endpoint              = "https://${var.backend_api_host}/v1/kitchen/messaging/ingress"
      http_method                      = "POST"
      invocation_rate_limit_per_second = 2
    }
  }
  create_connections = true
  connections = {
    kitchen_webhook = {
      authorization_type = "API_KEY"
      auth_parameters = {
        api_key = {
          key   = "X-API-KEY"
          value = var.backend_api_key
        }
      }
    }
  }

  # Dequeue and Send to an HTTP endpoint.
  pipes = {
    pos_webhook = {
      source = module.pos_webhook_queue.queue_arn
      target = aws_cloudwatch_event_api_destination.pos_webhook.arn

      source_parameters = {
        sqs_queue_parameters = {
          batch_size = 1
        }
      }
    }
  }
}

resource "aws_cloudwatch_event_api_destination" "pos_webhook" {
  name                             = "pos-webhook-destination"
  invocation_endpoint              = "https://${var.backend_api_host}/v1/pos/messaging/ingress"
  http_method                      = "POST"
  connection_arn                   = aws_cloudwatch_event_connection.pos_webhook.arn
  invocation_rate_limit_per_second = 2
}

resource "aws_cloudwatch_event_connection" "pos_webhook" {
  name               = "pos-webhook-connection"
  authorization_type = "API_KEY"
  auth_parameters {
    api_key {
      key   = "X-API-KEY"
      value = var.backend_api_key
    }
  }
}
