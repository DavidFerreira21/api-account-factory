# Changelog

Todas as mudanças relevantes deste projeto serão documentadas aqui.
Versão estável atual: `v1.0.0`.

Formato baseado em Keep a Changelog e Versionamento Semântico.

## [Unreleased]

### Added
- Placeholder para próximas mudanças.

## [1.0.0] - 2026-03-01

### Added
- Arquivo de exemplo `terraform/terraform.tfvars.example` para configuração segura.
- Outputs Terraform `api_rest_api_id` e `api_invoke_url`.
- Arquivos de governança open source:
  - `CONTRIBUTING.md`
  - `CODE_OF_CONDUCT.md`
  - `SECURITY.md`
- Seções de Quick Start, arquitetura, segurança, checklist de produção, limitações e roadmap no `README.md`.
- CI público com checks de qualidade e infraestrutura:
  - lint e formato Python
  - testes
  - `terraform fmt -check`
  - `terraform validate`
  - scan de segurança com Checkov

### Changed
- Bootstrap de contas passou a ser executado via Terraform Actions após deploy.
- Bootstrap atualizado com:
  - paginação de tags no Organizations
  - retry/backoff para propagação IAM
  - suporte a `fail_on_partial`
- IAM do bootstrap ajustado para chamadas necessárias (`ListParents`, `ListTagsForResource`, `UpdateItem`).
- Concorrência reservada de Lambda alterada para padrão `null` (evita erro de cota de concorrência não reservada).
- Grande expansão de parametrização Terraform:
  - naming (`name_prefix`, nomes de Lambdas, SFN role/policy/state machine)
  - runtime/timeout/memory
  - parâmetros de bootstrap e Step Function (`sfn_wait_seconds`, `bootstrap_fail_on_partial`)
  - tags e metadados (`solution_url`, `default_tags`)
- Migração de formatação Python para Ruff-only (remoção do Black do fluxo de lint/pre-commit).

### Fixed
- `bootstrap_accounts.py`: correção de `UpdateExpression` no DynamoDB para atributo reservado `Status` via `ExpressionAttributeNames`.
- Ajustes de formatação/lint para consistência entre ambiente local e CI.

## [0.1.0] - Histórico Inicial (pré-release sem tag)

### Added
- Estrutura inicial do projeto com:
  - API Lambda (`POST/GET /accounts`)
  - DynamoDB para estado de contas
  - Step Function para orquestração de criação de conta
  - Lambdas de validação, provisionamento e atualização de status
  - Terraform para provisionamento de infraestrutura
  - Testes iniciais e automações de lint/test

### Notes
- Este marco representa a base funcional inicial antes da formalização da release `v1.0.0`.
