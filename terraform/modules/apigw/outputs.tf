output "rest_api_id" {
  description = "ID do API Gateway"
  value       = aws_api_gateway_rest_api.this.id
}

output "invoke_url" {
  description = "URL base do stage"
  value       = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${var.region}.amazonaws.com/${var.stage_name}"
}

output "stage_arn" {
  description = "ARN do stage"
  value       = aws_api_gateway_stage.stage.arn
}

output "vpc_endpoint_id" {
  description = "ID do endpoint privado (quando criado)"
  value       = local.is_private_api ? aws_vpc_endpoint.execute_api[0].id : null
}
