variable "aws_region" {
  default = "us-east-1"
}

variable "api_gateway_vpc_id" {
  description = "VPC opcional para criar um endpoint privado do API Gateway"
  type        = string
  default     = ""
}

variable "api_gateway_vpc_subnet_ids" {
  description = "Subnets usadas pelo endpoint privado do API Gateway"
  type        = list(string)
  default     = []
}

variable "api_gateway_vpc_allowed_cidrs" {
  description = "Lista de CIDRs permitidos para acessar o endpoint privado do API Gateway (porta 443)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "api_gateway_stage_name" {
  description = "Nome do stage do API Gateway"
  type        = string
  default     = "prod"
}

variable "api_gateway_endpoint_type" {
  description = "Tipo do endpoint do API Gateway (REGIONAL, EDGE)"
  type        = string
  default     = "REGIONAL"
}

variable "api_gateway_log_retention_days" {
  description = "Dias de retention dos logs do API Gateway"
  type        = number
  default     = 30
}

variable "sfn_max_concurrent" {
  description = "Número máximo de execuções simultâneas permitidas para a Step Function, usado pela API para controle de capacidade"
  type        = number
  default     = 5
}

variable "lambda_reserved_concurrency" {
  description = "Limite padrão de concorrência reservada para as funções Lambda (null para não reservar)"
  type        = number
  default     = null
}
