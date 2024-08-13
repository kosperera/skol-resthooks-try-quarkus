# The http v2 requests are sent to an s3 bucket and
# the default bus queues it for the grab.
module "eventbus_default" {
  source = "terraform-aws-modules/eventbridge/aws"

  create_bus = false

  rules = {
    an_event_v2 = {
      description = "Captures all events (skinny, bulk or large payloads).",
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
    an_event_v2 = [
      # Send to a Queue and a Pipe will pick it up and
      # send it to the Lambda function (Backend Webhook Endpoint).
      {
        name            = "send-to-queue"
        arn             = module.queue.queue_arn
        dead_letter_arn = module.queue.dead_letter_queue_arn
        target_id       = "send-to-queue"
      }
    ]
  }
}
