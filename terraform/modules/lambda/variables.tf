variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN assumed by Lambda"
  type        = string
}

variable "handler" {
  description = "Lambda handler"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
}

variable "source_dir" {
  description = "Directory to package into the Lambda zip (mutually exclusive with source_file)"
  type        = string
  default     = null
}

variable "source_file" {
  description = "Single file to package into the Lambda zip (mutually exclusive with source_dir)"
  type        = string
  default     = null
}

variable "output_path" {
  description = "Path for the generated zip artifact"
  type        = string
}

variable "description" {
  description = "Lambda description"
  type        = string
  default     = ""
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 60
}

variable "memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 128
}

variable "publish" {
  description = "Whether to publish a new version on update"
  type        = bool
  default     = false
}

variable "layers" {
  description = "List of layer ARNs"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment variables for the Lambda"
  type        = map(string)
  default     = {}
}

variable "architectures" {
  description = "Instruction set architectures"
  type        = list(string)
  default     = ["x86_64"]
}

variable "tags" {
  description = "Tags applied to the Lambda"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of KMS key for Lambda environment encryption"
  type        = string
  default     = null
}
