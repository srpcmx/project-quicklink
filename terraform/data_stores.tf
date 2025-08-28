resource "aws_dynamodb_table" "mappings_table" {
  name           = "quicklink-mappings"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "shortCode"

  attribute {
    name = "shortCode"
    type = "S"
  }
}

resource "aws_cloudwatch_event_bus" "event_bus" {
  name = "quicklink-event-bus"
}