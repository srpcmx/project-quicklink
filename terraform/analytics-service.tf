# Create a new DynamoDB table for analytics data
resource "aws_dynamodb_table" "analytics_table" {
  name           = "quicklink-analytics"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "shortCode"

  attribute {
    name = "shortCode"
    type = "S"
  }
  
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}

# IAM Role and Policy for the Analytics Service
resource "aws_iam_role" "analytics_lambda_role" {
  name = "quicklink-analytics-service-role"

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

resource "aws_iam_policy" "analytics_lambda_policy" {
  name        = "quicklink-analytics-service-policy"
  description = "Policy for the QuickLink Analytics Service"

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
        Action   = "dynamodb:UpdateItem",
        Effect   = "Allow",
        Resource = aws_dynamodb_table.analytics_table.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "analytics_policy_attach" {
  role       = aws_iam_role.analytics_lambda_role.name
  policy_arn = aws_iam_policy.analytics_lambda_policy.arn
}

# Upload the JAR to S3
resource "aws_s3_object" "analytics_jar" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "analytics-service.jar"
  source = "../analytics-service/target/analytics-service-1.0.0.jar"
  etag   = filemd5("../analytics-service/target/analytics-service-1.0.0.jar")
}

# Create the Lambda Function
resource "aws_lambda_function" "analytics_service_lambda" {
  function_name = "analytics-service"
  role          = aws_iam_role.analytics_lambda_role.arn

  s3_bucket         = aws_s3_bucket.lambda_bucket.id
  s3_key            = aws_s3_object.analytics_jar.key
  s3_object_version = aws_s3_object.analytics_jar.version_id

  handler = "com.bro.quicklink.AnalyticsHandler"
  runtime = "java21"

  memory_size = 512
  timeout     = 10

  environment {
    variables = {
      ANALYTICS_TABLE_NAME = aws_dynamodb_table.analytics_table.name
    }
  }
}

# Create an EventBridge rule to trigger this Lambda
resource "aws_cloudwatch_event_rule" "url_accessed_rule" {
  name          = "UrlAccessedRule"
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name

  event_pattern = jsonencode({
    "source"      = ["com.bro.quicklink.redirect-service"],
    "detail-type" = ["UrlAccessedEvent"]
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.url_accessed_rule.name
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name
  arn       = aws_lambda_function.analytics_service_lambda.arn
}

# Add permission for EventBridge to invoke this Lambda
resource "aws_lambda_permission" "analytics_eventbridge_permission" {
  statement_id  = "AllowEventBridgeInvokeAnalytics"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analytics_service_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.url_accessed_rule.arn
}