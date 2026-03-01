# Contributing

Obrigado por contribuir com este projeto.

## Como contribuir
1. Abra uma issue descrevendo bug, melhoria ou proposta.
2. Crie uma branch a partir de `main`.
3. Faça mudanças pequenas e focadas.
4. Rode validações locais antes de abrir PR:
   - `make lint`
   - `make test`
   - `terraform -chdir=terraform fmt -recursive`
   - `terraform -chdir=terraform validate`
5. Abra PR com:
   - contexto do problema;
   - abordagem adotada;
   - riscos e impacto;
   - evidências de teste.

## Padrões
- Não commitar segredos, estados Terraform, `terraform.tfvars` real e artefatos zip.
- Manter compatibilidade com Python 3.11+ e Terraform 1.14+.
- Priorizar mudanças idempotentes e observáveis (logs, mensagens de erro claras).

## Convenções de Pull Request
- Título curto e direto.
- Descrição com "o que mudou", "por que mudou", "como validar".
- Se alterar comportamento funcional, atualize o `README.md` e/ou `documentation.md`.
