# Create a new S3 bucket to store our Lambda deployment packages
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "quicklink-lambda-deployments-bucket-${random_id.bucket_id.hex}"
}

# Explicitly enable versioning on the S3 bucket
resource "aws_s3_bucket_versioning" "lambda_bucket_versioning" {
  bucket = aws_s3_bucket.lambda_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Generate a unique ID to ensure the bucket name is globally unique
resource "random_id" "bucket_id" {
  byte_length = 8
}

# Upload the JAR file to the S3 bucket
resource "aws_s3_object" "lambda_jar" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "shortening-service.jar"
  source = "../shortening-service/target/shortening-service-0.0.1-SNAPSHOT.jar"
  
  # The etag still triggers a new upload when the local file changes
  etag = filemd5("../shortening-service/target/shortening-service-0.0.1-SNAPSHOT.jar")
}

# Create the Lambda function, now sourcing its code from S3
resource "aws_lambda_function" "shortening_service_lambda" {
  function_name = "shortening-service"
  role          = aws_iam_role.lambda_exec_role.arn
  
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_jar.key
  
  # Use the S3 object's version ID to track changes. This is more stable.
  # This tells Lambda to use the specific version of the JAR we just uploaded.
  s3_object_version = aws_s3_object.lambda_jar.version_id

  handler = "com.bro.quicklink.LambdaHandler"
  runtime = "java21"

  memory_size = 1024
  timeout     = 30

  # This depends on the versioning resource to ensure it's enabled first
  depends_on = [aws_s3_bucket_versioning.lambda_bucket_versioning]
}