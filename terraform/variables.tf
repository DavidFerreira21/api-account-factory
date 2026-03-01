variable "aws_region" {
  description = "Região AWS para provisionamento"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefixo padrão para nomes de recursos"
  type        = string
  default     = "accfactory"
  validation {
    condition = (
      trimspace(var.name_prefix) == var.name_prefix &&
      length(var.name_prefix) > 0 &&
      can(regex("^[A-Za-z0-9-]+$", var.name_prefix))
    )
    error_message = "name_prefix deve conter apenas letras, números e hífen, sem espaços."
  }
}

variable "solution_url" {
  description = "URL da solução usada na tag padrão Solution"
  type        = string
  default     = "https://github.com/DavidFerreira21/api-account-factory"
}

variable "default_tags" {
  description = "Tags adicionais aplicadas a todos os recursos"
  type        = map(string)
  default     = {}
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

variable "sfn_wait_seconds" {
  description = "Tempo de espera entre verificações de status na Step Function"
  type        = number
  default     = 300
}

variable "sfn_state_machine_name" {
  description = "Nome da Step Function de criação de conta"
  type        = string
  default     = "CreateAccountStateMachine"
  validation {
    condition = (
      trimspace(var.sfn_state_machine_name) == var.sfn_state_machine_name &&
      length(var.sfn_state_machine_name) > 0 &&
      can(regex("^[A-Za-z0-9-_]+$", var.sfn_state_machine_name))
    )
    error_message = "sfn_state_machine_name deve conter apenas letras, números, hífen e underscore, sem espaços."
  }
}

variable "sfn_role_name" {
  description = "Nome da role IAM usada pela Step Function"
  type        = string
  default     = "StepFunctionRole"
  validation {
    condition = (
      trimspace(var.sfn_role_name) == var.sfn_role_name &&
      length(var.sfn_role_name) > 0 &&
      can(regex("^[A-Za-z0-9+=,.@_-]+$", var.sfn_role_name))
    )
    error_message = "sfn_role_name contém caracteres inválidos para nome IAM."
  }
}

variable "sfn_policy_name" {
  description = "Nome da policy IAM anexada à role da Step Function"
  type        = string
  default     = "StepFunctionPolicy"
  validation {
    condition = (
      trimspace(var.sfn_policy_name) == var.sfn_policy_name &&
      length(var.sfn_policy_name) > 0 &&
      can(regex("^[A-Za-z0-9+=,.@_-]+$", var.sfn_policy_name))
    )
    error_message = "sfn_policy_name contém caracteres inválidos para nome IAM."
  }
}

variable "lambda_runtime_default" {
  description = "Runtime padrão para funções Lambda"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout_provision" {
  description = "Timeout da Lambda de provisionamento de conta"
  type        = number
  default     = 600
}

variable "lambda_timeout_bootstrap" {
  description = "Timeout da Lambda de bootstrap"
  type        = number
  default     = 300
}

variable "lambda_memory_bootstrap" {
  description = "Memória (MB) da Lambda de bootstrap"
  type        = number
  default     = 512
}

variable "lambda_reserved_concurrency" {
  description = "Limite padrão de concorrência reservada para as funções Lambda (null para não reservar)"
  type        = number
  default     = null
}

variable "bootstrap_fail_on_partial" {
  description = "Quando true, o bootstrap falha se houver falhas parciais de registro"
  type        = bool
  default     = false
}

variable "lambda_name_accounts_api" {
  description = "Nome da Lambda da API"
  type        = string
  default     = ""
  validation {
    condition = (
      var.lambda_name_accounts_api == "" ||
      (
        trimspace(var.lambda_name_accounts_api) == var.lambda_name_accounts_api &&
        length(var.lambda_name_accounts_api) <= 64 &&
        can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_accounts_api))
      )
    )
    error_message = "lambda_name_accounts_api deve ser vazio (fallback) ou um nome Lambda válido sem espaços."
  }
}

variable "lambda_name_validate_fields" {
  description = "Nome da Lambda de validação"
  type        = string
  default     = "Validate_fieldsLambda"
  validation {
    condition = (
      trimspace(var.lambda_name_validate_fields) == var.lambda_name_validate_fields &&
      length(var.lambda_name_validate_fields) > 0 &&
      length(var.lambda_name_validate_fields) <= 64 &&
      can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_validate_fields))
    )
    error_message = "lambda_name_validate_fields deve ser um nome Lambda válido sem espaços."
  }
}

variable "lambda_name_provision_account" {
  description = "Nome da Lambda de provisionamento"
  type        = string
  default     = "ProvisionAccountLambda"
  validation {
    condition = (
      trimspace(var.lambda_name_provision_account) == var.lambda_name_provision_account &&
      length(var.lambda_name_provision_account) > 0 &&
      length(var.lambda_name_provision_account) <= 64 &&
      can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_provision_account))
    )
    error_message = "lambda_name_provision_account deve ser um nome Lambda válido sem espaços."
  }
}

variable "lambda_name_check_status" {
  description = "Nome da Lambda de checagem de status"
  type        = string
  default     = "CheckAccountStatusLambda"
  validation {
    condition = (
      trimspace(var.lambda_name_check_status) == var.lambda_name_check_status &&
      length(var.lambda_name_check_status) > 0 &&
      length(var.lambda_name_check_status) <= 64 &&
      can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_check_status))
    )
    error_message = "lambda_name_check_status deve ser um nome Lambda válido sem espaços."
  }
}

variable "lambda_name_bootstrap_accounts" {
  description = "Nome da Lambda de bootstrap; vazio usa <name_prefix>-bootstrap-accounts"
  type        = string
  default     = ""
  validation {
    condition = (
      var.lambda_name_bootstrap_accounts == "" ||
      (
        trimspace(var.lambda_name_bootstrap_accounts) == var.lambda_name_bootstrap_accounts &&
        length(var.lambda_name_bootstrap_accounts) <= 64 &&
        can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_bootstrap_accounts))
      )
    )
    error_message = "lambda_name_bootstrap_accounts deve ser vazio (fallback) ou um nome Lambda válido sem espaços."
  }
}

variable "lambda_name_update_status" {
  description = "Nome da Lambda de atualização de sucesso"
  type        = string
  default     = "UpdateSucceedStatusLambda"
  validation {
    condition = (
      trimspace(var.lambda_name_update_status) == var.lambda_name_update_status &&
      length(var.lambda_name_update_status) > 0 &&
      length(var.lambda_name_update_status) <= 64 &&
      can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_update_status))
    )
    error_message = "lambda_name_update_status deve ser um nome Lambda válido sem espaços."
  }
}

variable "lambda_name_update_failed_status" {
  description = "Nome da Lambda de atualização de falha"
  type        = string
  default     = "UpdateFailedStatusLambda"
  validation {
    condition = (
      trimspace(var.lambda_name_update_failed_status) == var.lambda_name_update_failed_status &&
      length(var.lambda_name_update_failed_status) > 0 &&
      length(var.lambda_name_update_failed_status) <= 64 &&
      can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_update_failed_status))
    )
    error_message = "lambda_name_update_failed_status deve ser um nome Lambda válido sem espaços."
  }
}

variable "lambda_name_trigger_sfn" {
  description = "Nome da Lambda que dispara a Step Function"
  type        = string
  default     = "TriggerSFNLambda"
  validation {
    condition = (
      trimspace(var.lambda_name_trigger_sfn) == var.lambda_name_trigger_sfn &&
      length(var.lambda_name_trigger_sfn) > 0 &&
      length(var.lambda_name_trigger_sfn) <= 64 &&
      can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_trigger_sfn))
    )
    error_message = "lambda_name_trigger_sfn deve ser um nome Lambda válido sem espaços."
  }
}
