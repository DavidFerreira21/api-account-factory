variable "aws_region" {
  default = "us-east-1"
}

variable "api_gateway_vpc_id" {
  description = "VPC opcional para criar um endpoint privado do API Gateway"
  type        = string
  default     = "vpc-044c821c062e4a101"
}

variable "api_gateway_vpc_subnet_ids" {
  description = "Subnets usadas pelo endpoint privado do API Gateway"
  type        = list(string)
  default     = ["subnet-0a6836ecb007da421"]
}

variable "api_gateway_vpc_allowed_cidrs" {
  description = "Lista de CIDRs permitidos para acessar o endpoint privado do API Gateway (porta 443)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
