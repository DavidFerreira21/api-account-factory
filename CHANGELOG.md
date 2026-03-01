# Changelog

Todas as mudanças relevantes deste projeto serão documentadas aqui.

## [Unreleased]

### Added
- `terraform/terraform.tfvars.example` para configuração segura de ambiente.
- Outputs Terraform `api_rest_api_id` e `api_invoke_url`.
- Documentação de Quick Start e hardening para repositório público.
- Arquivos de governança: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`.

### Changed
- Bootstrap executado via Terraform Actions no deploy.
- Bootstrap atualizado para paginação de tags no Organizations.
- Bootstrap tolera falha parcial quando `fail_on_partial=false`.
- Ajustes de IAM para bootstrap (`ListParents`, `ListTagsForResource`, `UpdateItem`).
- `lambda_reserved_concurrency` padrão alterado para `null`.

### Fixed
- Correção de palavra reservada DynamoDB em `Status` usando `ExpressionAttributeNames`.

