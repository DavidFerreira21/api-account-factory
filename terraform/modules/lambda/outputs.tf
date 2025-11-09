output "arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "invoke_arn" {
  description = "Lambda invoke ARN"
  value       = aws_lambda_function.this.invoke_arn
}

output "qualified_arn" {
  description = "Qualified ARN (when publish=true)"
  value       = aws_lambda_function.this.qualified_arn
}

output "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the package"
  value       = aws_lambda_function.this.source_code_hash
}
