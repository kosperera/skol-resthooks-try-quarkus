module "sqs_lambdafn" {
  source = "terraform-aws-modules/sqs/aws"

  name = "sb-sqs-kitchensync-lambdafn-01"

  create_dlq = true
  redrive_policy = {
    maxReceiveCount = 10
  }
  create_dlq_redrive_allow_policy = false
  dlq_sqs_managed_sse_enabled     = true

  create_queue_policy = true
  queue_policy_statements = {
    queue = {
      sid     = "AllowSendMessage"
      actions = ["sqs:SendMessage"]

      principals = [{
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }]
    }
  }
  sqs_managed_sse_enabled = true
}

module "sqs_lambdawebapi" {
  source = "terraform-aws-modules/sqs/aws"

  name = "sb-sqs-kitchensync-lambdawebapi-01"

  create_dlq = true
  redrive_policy = {
    maxReceiveCount = 10
  }
  create_dlq_redrive_allow_policy = false
  dlq_sqs_managed_sse_enabled     = true

  create_queue_policy = true
  queue_policy_statements = {
    queue = {
      sid     = "AllowSendMessage"
      actions = ["sqs:SendMessage"]

      principals = [{
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }]
    }
  }
  sqs_managed_sse_enabled = true
}
