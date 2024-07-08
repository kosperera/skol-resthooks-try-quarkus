# Source https://www.kitopi.com/post/authorization-in-machine-to-machine-integrations-using-amazon-cognito
resource "aws_cognito_user_pool" "pool" {
  name = "usp-skol-kitchensync-01"

  account_recovery_setting {
    recovery_mechanism {
      name     = "admin_only"
      priority = 1
    }
  }
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
  # HACK: Source https://github.com/hashicorp/terraform-provider-aws/issues/21654#issuecomment-1058245347
  lifecycle {
    ignore_changes = [schema]
  }
}

resource "aws_cognito_user_pool_domain" "domain" {
  domain       = "kitchensync"
  user_pool_id = join("", aws_cognito_user_pool.pool.*.id)
}

resource "aws_cognito_resource_server" "resource" {
  name = "Kitchen sync"
  # FIXME: identifier   = format("%s%s", aws_api_gateway_deployment.this.invoke_url, aws_api_gateway_stage.this.stage_name)
  identifier   = "kitchensync"
  user_pool_id = join("", aws_cognito_user_pool.pool.*.id)

  scope {
    scope_name        = "post"
    scope_description = "Publish notifications"
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "doordash-events"
  user_pool_id = join("", aws_cognito_user_pool.pool.*.id)

  access_token_validity                = 24
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = aws_cognito_resource_server.resource.scope_identifiers
  enable_token_revocation              = true
  generate_secret                      = true
}
