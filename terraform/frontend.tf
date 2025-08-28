# Create an S3 bucket for the frontend website
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "quicklink-frontend-bucket-${random_id.bucket_id.hex}"
  force_destroy = true									  
}

# Set bucket ownership to BucketOwnerEnforced to disable ACLs
resource "aws_s3_bucket_ownership_controls" "frontend_ownership" {
  bucket = aws_s3_bucket.frontend_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Make the bucket publicly readable
resource "aws_s3_bucket_public_access_block" "frontend_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false			 
  restrict_public_buckets = false
  depends_on = [aws_s3_bucket_ownership_controls.frontend_ownership]
}

# 4) Bucket policy: lectura pública SOLO por policy (no ACL)
data "aws_iam_policy_document" "frontend_public_read" {
  statement {
    sid     = "PublicReadGetObject"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    principals {
        type = "*"
        identifiers = ["*"]
    }
    resources = ["${aws_s3_bucket.frontend_bucket.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
																						  
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = data.aws_iam_policy_document.frontend_public_read.json
  depends_on = [
    aws_s3_bucket_public_access_block.frontend_public_access,
    aws_s3_bucket_ownership_controls.frontend_ownership
  ]
	
}

# Configure the S3 bucket for static website hosting
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id
  index_document {
    suffix = "index.html"
  }
  depends_on = [aws_s3_bucket_policy.frontend_bucket_policy]
}

# Upload the index.html file to the S3 bucket
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "index.html"
  content      = templatefile("../frontend/index.html", {
    apiUrl = aws_apigatewayv2_stage.default_stage.invoke_url
  })
  content_type = "text/html"
  etag         = md5(templatefile("../frontend/index.html", {
    apiUrl = aws_apigatewayv2_stage.default_stage.invoke_url
  }))
  depends_on = [
    aws_s3_bucket_ownership_controls.frontend_ownership,
    aws_s3_bucket_public_access_block.frontend_public_access
  ]
}

# Output the public URL for the website
output "website_url" {
  description = "The public URL for the QuickLink frontend."
  value       = "http://${aws_s3_bucket_website_configuration.frontend_website.website_endpoint}"
}