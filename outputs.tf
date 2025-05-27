output "api_endpoint" {
  value = "${aws_api_gateway_stage.log_service_stage.invoke_url}/logs"
}

output "api_key" {
  value     = aws_api_gateway_api_key.log_service_key.value
  sensitive = true
}