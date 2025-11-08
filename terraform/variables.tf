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

variable "api_gateway_vpc_sg_ids" {
  description = "Security groups associados ao endpoint privado do API Gateway"
  type        = list(string)
  default     = []
}
