output "api_endpoint_url" {
  description = "The URL of the deployed API Gateway endpoint."
  value       = aws_apigatewayv2_stage.default_stage.invoke_url
}