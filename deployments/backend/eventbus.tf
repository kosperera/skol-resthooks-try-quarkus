module "eventbus" {
  source = "terraform-aws-modules/eventbridge/aws"

  bus_name = "sb-evb-ksync-events-01"

  rules = {
    an_event_v1 = {
      description   = "Capture order notification.",
      event_pattern = jsonencode({ "detail-type" : ["Order.Notification"] })
      state = "ENABLED"
    }
  }

  targets = {
    an_event_v1 = [
      # Send to a Queue and a Pipe will pick it up and
      # send it to the Lambda function (Backend Webhook Endpoint).
      {
        name            = "send-to-queue"
        arn             = module.queue.queue_arn
        dead_letter_arn = module.queue.dead_letter_queue_arn
        target_id       = "send-to-queue"
      },

      # Forwards to a backend webhook (http endpoint).
      # {
      #   name            = "send-to-webhook"
      #   destination     = "external_webhook"
      #   attach_role_arn = true
      # }
    ]
  }

  pipes = {
    external_webhook = {
      # create_role = false
      role_arn = aws_iam_role.pipe.arn

      source = module.queue.queue_arn
      source_parameters = {
        sqs_queue_parameters = {
          batch_size = 1
        }
      }

      enrichment = module.func_enrich_event_v2.lambda_function_arn

      target = module.eventbus.eventbridge_api_destination_arns["external_webhook"]

      log_configuration = {
        level = "INFO"
        cloudwatch_logs_log_destination = {
          log_group_arn = aws_cloudwatch_log_group.this.arn
        }
      }
    }
  }

  # Skip the Queues, just send directly
  # to a Backend Webhook Endpoint.

  create_connections = true
  connections = {
    external_webhook = {
      authorization_type = "API_KEY"
      auth_parameters = {
        api_key = {
          key   = "X-API-KEY"
          value = var.backend_api_key
        }
      }
    }
  }

  create_api_destinations       = true
  attach_api_destination_policy = true
  api_destinations = {
    external_webhook = {
      description                      = "External webhook accepts order notifications and whatnot."
      invocation_endpoint              = "https://${var.backend_api_host}/v1/kitchen/messaging/ingress"
      http_method                      = "POST"
      invocation_rate_limit_per_second = 2
    }
  }

  attach_cloudwatch_policy = true
  cloudwatch_target_arns   = [aws_cloudwatch_log_group.this.arn]
}

resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/events/${module.eventbus.eventbridge_bus_name}"

  tags = {
    Name = "${module.eventbus.eventbridge_bus_name}-log-group"
  }
}

data "aws_iam_policy_document" "assume_role_pipe" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["pipes.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pipe" {
  name               = "external-webhook-pipe"
  assume_role_policy = data.aws_iam_policy_document.assume_role_pipe.json
}

# PowerUserAccess policy is used here just for testing purposes
resource "aws_iam_role_policy_attachment" "pipe" {
  role       = aws_iam_role.pipe.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}
