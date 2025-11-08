variable "name_prefix" {
  description = "Prefixo usado para nomear os recursos do API Gateway"
  type        = string
}

variable "stage_name" {
  description = "Nome do stage do API Gateway"
  type        = string
  default     = "prod"
}

variable "lambda_function_name" {
  description = "Nome da função Lambda que receberá chamadas do API Gateway"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN da função Lambda para o aws_lambda_permission"
  type        = string
}

variable "region" {
  description = "Região AWS"
  type        = string
}

variable "openapi_template_path" {
  description = "Caminho para o arquivo OpenAPI usado para criar o API Gateway"
  type        = string
}

variable "log_retention_days" {
  description = "Retention dos logs do API Gateway"
  type        = number
  default     = 30
}

variable "endpoint_type" {
  description = "Tipo do endpoint (REGIONAL, EDGE) usado quando nenhum VPC é informado"
  type        = string
  default     = "REGIONAL"
}

variable "vpc_id" {
  description = "ID da VPC para criar um endpoint privado (Interface). Quando vazio, API pública."
  type        = string
  default     = ""
}

variable "vpc_subnet_ids" {
  description = "Subnets usadas pelo endpoint privado (obrigatórias quando vpc_id for definido)"
  type        = list(string)
  default     = []
}

variable "vpc_endpoint_security_group_ids" {
  description = "Security Groups aplicados ao endpoint privado"
  type        = list(string)
  default     = []
}
