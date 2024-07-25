# Large Messages (Payloads) are send to an S3 Bucket and 
# EventBridge will forward that to a Queue.
module "default_bridge" {
  source = "terraform-aws-modules/eventbridge/aws"

  create_bus = false

  rules = {
    large_messages = {
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
    large_messages = [
      # Send to a Queue and a Pipe will pick it up and
      # send it to the Lambda function (Backend Webhook Endpoint).
      {
        name            = "send-to-lambdawebapi-queue"
        arn             = module.sqs_lambdawebapi.queue_arn
        dead_letter_arn = module.sqs_lambdawebapi.dead_letter_queue_arn
        target_id       = "send-to-lambdawebapi-queue"
      }
    ]
  }
}
