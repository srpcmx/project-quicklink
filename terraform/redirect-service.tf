# IAM Role and Policy for the Redirect Service
resource "aws_iam_role" "redirect_lambda_role" {
  name = "quicklink-redirect-service-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "redirect_lambda_policy" {
  name        = "quicklink-redirect-service-policy"
  description = "Policy for the QuickLink Redirect Service"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action   = "dynamodb:GetItem",
        Effect   = "Allow",
        Resource = aws_dynamodb_table.mappings_table.arn
      },
      {
        Action   = "events:PutEvents",
        Effect   = "Allow",
        Resource = aws_cloudwatch_event_bus.event_bus.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "redirect_policy_attach" {
  role       = aws_iam_role.redirect_lambda_role.name
  policy_arn = aws_iam_policy.redirect_lambda_policy.arn
}

# Upload the JAR to S3
resource "aws_s3_object" "redirect_jar" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "redirect-service.jar"
  source = "../redirect-service/target/redirect-service-1.0.0.jar"
  etag   = filemd5("../redirect-service/target/redirect-service-1.0.0.jar")
}

# Create the Lambda Function
resource "aws_lambda_function" "redirect_service_lambda" {
  function_name = "redirect-service"
  role          = aws_iam_role.redirect_lambda_role.arn

  s3_bucket         = aws_s3_bucket.lambda_bucket.id
  s3_key            = aws_s3_object.redirect_jar.key
  s3_object_version = aws_s3_object.redirect_jar.version_id

  handler = "com.bro.quicklink.RedirectHandler"
  runtime = "java21"

  memory_size = 512
  timeout     = 10

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.mappings_table.name
      EVENT_BUS_NAME = aws_cloudwatch_event_bus.event_bus.name
    }
  }
}

# Add a route on the existing API Gateway for redirects
resource "aws_apigatewayv2_route" "redirect_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "GET /{shortCode}"
  target    = "integrations/${aws_apigatewayv2_integration.redirect_integration.id}"
}

resource "aws_apigatewayv2_integration" "redirect_integration" {
  api_id               = aws_apigatewayv2_api.lambda_api.id
  integration_type     = "AWS_PROXY"
  integration_uri      = aws_lambda_function.redirect_service_lambda.invoke_arn
  payload_format_version = "2.0"
}

# Add permission for API Gateway to invoke this new Lambda
resource "aws_lambda_permission" "redirect_api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvokeRedirect"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.redirect_service_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}