# Create a DynamoDB table to store WebSocket connection IDs
resource "aws_dynamodb_table" "connections_table" {
  name           = "quicklink-connections"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "connectionId"

  attribute {
    name = "connectionId"
    type = "S"
  }
}

# Create the WebSocket API
resource "aws_apigatewayv2_api" "websocket_api" {
  name                       = "quicklink-websocket-api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

# IAM Role and Policy for the Dashboard Service
resource "aws_iam_role" "dashboard_lambda_role" {
  name = "quicklink-dashboard-service-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "dashboard_lambda_policy" {
  name        = "quicklink-dashboard-service-policy"
  description = "Policy for the QuickLink Dashboard Service"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action   = ["dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:Scan"],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.connections_table.arn
      },
      {
        Action   = ["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:ListStreams"],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.analytics_table.stream_arn
      },
      {
        Action   = "execute-api:ManageConnections",
        Effect   = "Allow",
        Resource = "arn:aws:execute-api:*:*:${aws_apigatewayv2_api.websocket_api.id}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dashboard_policy_attach" {
  role       = aws_iam_role.dashboard_lambda_role.name
  policy_arn = aws_iam_policy.dashboard_lambda_policy.arn
}

# Upload the JAR to S3
resource "aws_s3_object" "dashboard_jar" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "dashboard-service.jar"
  source = "../dashboard-service/target/dashboard-service-1.0.0.jar"
  etag   = filemd5("../dashboard-service/target/dashboard-service-1.0.0.jar")
}

# Add this new resource to upload the dashboard.html file
resource "aws_s3_object" "dashboard_html" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "dashboard.html"
  content      = templatefile("../frontend/dashboard.html", {
    websocketUrl = aws_apigatewayv2_stage.websocket_stage.invoke_url
  })
  content_type = "text/html"
  etag         = md5(templatefile("../frontend/dashboard.html", {
    websocketUrl = aws_apigatewayv2_stage.websocket_stage.invoke_url
  }))
}

# Create the Lambda Function
resource "aws_lambda_function" "dashboard_service_lambda" {
  function_name = "dashboard-service"
  role          = aws_iam_role.dashboard_lambda_role.arn
  s3_bucket         = aws_s3_bucket.lambda_bucket.id
  s3_key            = aws_s3_object.dashboard_jar.key
  s3_object_version = aws_s3_object.dashboard_jar.version_id
  handler = "com.bro.quicklink.DashboardHandler"
  runtime = "java21"
  memory_size = 512
  timeout     = 10
  environment {
    variables = {
      CONNECTIONS_TABLE_NAME = aws_dynamodb_table.connections_table.name
      WEBSOCKET_API_ID       = aws_apigatewayv2_api.websocket_api.id
      WEBSOCKET_API_STAGE    = aws_apigatewayv2_stage.websocket_stage.name
    }
  }
}

# Create an event source mapping to trigger the Lambda from the DynamoDB stream
resource "aws_lambda_event_source_mapping" "analytics_stream_mapping" {
  event_source_arn  = aws_dynamodb_table.analytics_table.stream_arn
  function_name     = aws_lambda_function.dashboard_service_lambda.arn
  starting_position = "LATEST"
}

# Configure WebSocket API routes and deployment stage
resource "aws_apigatewayv2_integration" "websocket_integration" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.dashboard_service_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "connect_route" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.websocket_integration.id}"
}

resource "aws_apigatewayv2_route" "disconnect_route" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.websocket_integration.id}"
}

resource "aws_apigatewayv2_stage" "websocket_stage" {
  api_id      = aws_apigatewayv2_api.websocket_api.id
  name        = "prod"
  auto_deploy = true
}

resource "aws_lambda_permission" "websocket_permission" {
  statement_id  = "AllowAPIGatewayInvokeDashboard"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dashboard_service_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket_api.execution_arn}/*/*"
}

# Output the WebSocket URL
output "websocket_url" {
  description = "The URL for the WebSocket API."
  value       = aws_apigatewayv2_stage.websocket_stage.invoke_url
}