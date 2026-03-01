variable "aws_region" {
  description = "AWS region used for provisioning"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Default prefix for resource names"
  type        = string
  default     = "accfactory"
  validation {
    condition = (
      trimspace(var.name_prefix) == var.name_prefix &&
      length(var.name_prefix) > 0 &&
      can(regex("^[A-Za-z0-9-]+$", var.name_prefix))
    )
    error_message = "name_prefix must contain only letters, numbers, and hyphens, with no spaces."
  }
}

variable "solution_url" {
  description = "Solution URL used in the default Solution tag"
  type        = string
  default     = "https://github.com/DavidFerreira21/api-account-factory"
}

variable "default_tags" {
  description = "Additional tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "api_gateway_vpc_id" {
  description = "Optional VPC ID to create a private API Gateway endpoint"
  type        = string
  default     = ""
}

variable "api_gateway_vpc_subnet_ids" {
  description = "Subnets used by the private API Gateway endpoint"
  type        = list(string)
  default     = []
}

variable "api_gateway_vpc_allowed_cidrs" {
  description = "List of CIDRs allowed to access the private API Gateway endpoint (port 443)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "api_gateway_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "prod"
}

variable "api_gateway_endpoint_type" {
  description = "API Gateway endpoint type (REGIONAL, EDGE)"
  type        = string
  default     = "REGIONAL"
}

variable "api_gateway_log_retention_days" {
  description = "API Gateway log retention period in days"
  type        = number
  default     = 30
}

variable "sfn_max_concurrent" {
  description = "Maximum number of concurrent Step Function executions allowed (used by API capacity control)"
  type        = number
  default     = 5
}

variable "sfn_wait_seconds" {
  description = "Wait time between status checks in the Step Function"
  type        = number
  default     = 300
}

variable "sfn_state_machine_name" {
  description = "Account creation Step Function name"
  type        = string
  default     = "CreateAccountStateMachine"
  validation {
    condition = (
      trimspace(var.sfn_state_machine_name) == var.sfn_state_machine_name &&
      length(var.sfn_state_machine_name) > 0 &&
      can(regex("^[A-Za-z0-9-_]+$", var.sfn_state_machine_name))
    )
    error_message = "sfn_state_machine_name must contain only letters, numbers, hyphens, and underscores, with no spaces."
  }
}

variable "sfn_role_name" {
  description = "IAM role name used by the Step Function"
  type        = string
  default     = "StepFunctionRole"
  validation {
    condition = (
      trimspace(var.sfn_role_name) == var.sfn_role_name &&
      length(var.sfn_role_name) > 0 &&
      can(regex("^[A-Za-z0-9+=,.@_-]+$", var.sfn_role_name))
    )
    error_message = "sfn_role_name contains invalid IAM name characters."
  }
}

variable "sfn_policy_name" {
  description = "IAM policy name attached to the Step Function role"
  type        = string
  default     = "StepFunctionPolicy"
  validation {
    condition = (
      trimspace(var.sfn_policy_name) == var.sfn_policy_name &&
      length(var.sfn_policy_name) > 0 &&
      can(regex("^[A-Za-z0-9+=,.@_-]+$", var.sfn_policy_name))
    )
    error_message = "sfn_policy_name contains invalid IAM name characters."
  }
}

variable "lambda_runtime_default" {
  description = "Default runtime for Lambda functions"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout_provision" {
  description = "Timeout for account provisioning Lambda"
  type        = number
  default     = 600
}

variable "lambda_timeout_bootstrap" {
  description = "Timeout for bootstrap Lambda"
  type        = number
  default     = 300
}

variable "lambda_memory_bootstrap" {
  description = "Memory (MB) for bootstrap Lambda"
  type        = number
  default     = 512
}

variable "lambda_reserved_concurrency" {
  description = "Default reserved concurrency for Lambda functions (null to leave unreserved)"
  type        = number
  default     = null
}

variable "bootstrap_fail_on_partial" {
  description = "When true, bootstrap fails if there are partial write failures"
  type        = bool
  default     = false
}

variable "lambda_name_accounts_api" {
  description = "API Lambda function name"
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
    error_message = "lambda_name_accounts_api must be empty (fallback) or a valid Lambda name with no spaces."
  }
}

variable "lambda_name_validate_fields" {
  description = "Validation Lambda function name"
  type        = string
  default     = "Validate_fieldsLambda"
  validation {
    condition = (
      trimspace(var.lambda_name_validate_fields) == var.lambda_name_validate_fields &&
      length(var.lambda_name_validate_fields) > 0 &&
      length(var.lambda_name_validate_fields) <= 64 &&
      can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_validate_fields))
    )
    error_message = "lambda_name_validate_fields must be a valid Lambda name with no spaces."
  }
}

variable "lambda_name_provision_account" {
  description = "Provisioning Lambda function name"
  type        = string
  default     = "ProvisionAccountLambda"
  validation {
    condition = (
      trimspace(var.lambda_name_provision_account) == var.lambda_name_provision_account &&
      length(var.lambda_name_provision_account) > 0 &&
      length(var.lambda_name_provision_account) <= 64 &&
      can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_provision_account))
    )
    error_message = "lambda_name_provision_account must be a valid Lambda name with no spaces."
  }
}

variable "lambda_name_check_status" {
  description = "Status-check Lambda function name"
  type        = string
  default     = "CheckAccountStatusLambda"
  validation {
    condition = (
      trimspace(var.lambda_name_check_status) == var.lambda_name_check_status &&
      length(var.lambda_name_check_status) > 0 &&
      length(var.lambda_name_check_status) <= 64 &&
      can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_check_status))
    )
    error_message = "lambda_name_check_status must be a valid Lambda name with no spaces."
  }
}

variable "lambda_name_bootstrap_accounts" {
  description = "Bootstrap Lambda name; when empty uses <name_prefix>-bootstrap-accounts"
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
    error_message = "lambda_name_bootstrap_accounts must be empty (fallback) or a valid Lambda name with no spaces."
  }
}

variable "lambda_name_update_status" {
  description = "Success-status update Lambda function name"
  type        = string
  default     = "UpdateSucceedStatusLambda"
  validation {
    condition = (
      trimspace(var.lambda_name_update_status) == var.lambda_name_update_status &&
      length(var.lambda_name_update_status) > 0 &&
      length(var.lambda_name_update_status) <= 64 &&
      can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_update_status))
    )
    error_message = "lambda_name_update_status must be a valid Lambda name with no spaces."
  }
}

variable "lambda_name_update_failed_status" {
  description = "Failure-status update Lambda function name"
  type        = string
  default     = "UpdateFailedStatusLambda"
  validation {
    condition = (
      trimspace(var.lambda_name_update_failed_status) == var.lambda_name_update_failed_status &&
      length(var.lambda_name_update_failed_status) > 0 &&
      length(var.lambda_name_update_failed_status) <= 64 &&
      can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_update_failed_status))
    )
    error_message = "lambda_name_update_failed_status must be a valid Lambda name with no spaces."
  }
}

variable "lambda_name_trigger_sfn" {
  description = "Lambda function name that starts the Step Function"
  type        = string
  default     = "TriggerSFNLambda"
  validation {
    condition = (
      trimspace(var.lambda_name_trigger_sfn) == var.lambda_name_trigger_sfn &&
      length(var.lambda_name_trigger_sfn) > 0 &&
      length(var.lambda_name_trigger_sfn) <= 64 &&
      can(regex("^[A-Za-z0-9-_]+$", var.lambda_name_trigger_sfn))
    )
    error_message = "lambda_name_trigger_sfn must be a valid Lambda name with no spaces."
  }
}
