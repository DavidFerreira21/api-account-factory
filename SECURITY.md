# Security Policy

## Como reportar vulnerabilidades

Não abra vulnerabilidades em issues públicas.

Use um destes canais:
1. GitHub Security Advisory (preferencial), em "Report a vulnerability".
2. Se indisponível, abra issue com título `SECURITY: private report requested` sem detalhes sensíveis, para coordenar canal privado.

## O que incluir no reporte
- Componente afetado (Terraform, Lambda, API Gateway, Step Functions).
- Vetor de ataque.
- Evidência e impacto.
- Passos para reproduzir.
- Sugestão de mitigação (se houver).

## Escopo de segurança do projeto
- IAM permissivo em alguns pontos para viabilizar bootstrap/provisionamento inicial.
- Endpoint API pode operar em modo público (`REGIONAL`) ou privado (`PRIVATE + VPC endpoint`).
- Dados operacionais são registrados em CloudWatch.

## SLA
- Triagem inicial: até 8 dias úteis.
- Atualizações de progresso: periódicas até fechamento.
