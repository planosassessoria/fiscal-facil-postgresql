# Demanda Técnica — Módulo SPED Fiscal (Backend)

> Destinatário: Time Backend Fiscal Fácil  
> Referência de schema: schema_sped.sql  
> Data: Junho/2026

---

## 1. Visão Geral

Este documento orienta a implementação backend do módulo SPED Fiscal (EFD ICMS/IPI) com base na modelagem atual do banco.

Objetivos principais:

- Importar e persistir arquivos SPED com estrutura flexível (JSONB)
- Preservar hierarquia física dos registros (pai-filho)
- Controlar execução por protocolo/job com etapas granulares
- Permitir auditoria operacional completa (quem fez, quando fez, em que etapa)
- Suportar evolução de regras sem quebrar o layout a cada versão da Receita

---

## 2. Princípios de Arquitetura

- Tabela única de registros SPED com JSONB para eliminar rigidez de layout
- Auto-relacionamento para manter árvore física do arquivo (registro pai e filho)
- Separação entre dado do arquivo e estado operacional (job/stages/events)
- Rastreabilidade por protocolo para suporte, auditoria e acompanhamento em tempo real
- Governança multi-tenant via tenant_id, est_id e usuário responsável

---

## 3. Modelagem de Banco (Resumo)

### 3.1 Arquivo de Origem

Tabela sped.sped_files:

- sped_file_id: identificador interno do arquivo
- document: CPF/CNPJ do declarante (11 ou 14 dígitos)
- ie: inscrição estadual quando aplicável
- reference_period: período fiscal
- layout_version: versão do leiaute SPED
- source_file_name / source_file_sha256
- total_lines / imported_at
- created_at / updated_at

Regras importantes:

- source_file_sha256 com unique para reduzir duplicidade
- document validado por check regex
- sem coluna de status operacional no arquivo

### 3.2 Registros SPED

Tabela sped.sped_records:

- sped_record_id
- sped_file_id
- block_code / record_code
- line_number
- parent_sped_record_id
- record_payload (JSONB)
- line_sha256 / hierarchy_level
- created_at / updated_at

Regras importantes:

- unique por arquivo e linha física: (sped_file_id, line_number)
- trigger + função validam consistência pai-filho
- pai precisa existir, ser do mesmo arquivo e estar em linha anterior

### 3.3 Protocolo e Execução

Tabela sped.sped_jobs:

- sped_job_id / sped_file_id
- tenant_id / est_id
- protocol_code (unique)
- job_type
- workflow_status
- current_stage_code
- progress_percent
- requested_by_email
- started_at / finished_at / failed_at / last_heartbeat_at
- job_metadata
- created_at / updated_at

Tabela sped.sped_job_stages:

- sped_job_stage_id / sped_job_id
- stage_code / stage_order
- stage_status
- responsible_by_email
- stage_summary / stage_payload
- started_at / finished_at
- created_at / updated_at

Tabela sped.sped_job_events:

- sped_job_event_id / sped_job_id
- event_code / event_title / event_description
- previous_workflow_status / new_workflow_status
- created_by_email
- event_payload
- created_at / updated_at

---

## 4. Estado Operacional (Workflow)

Status de alto nível (sped_jobs.workflow_status):

- RECEIVED
- IMPORTED
- IN_AUDIT
- AUDIT_PARTIAL
- AUDIT_COMPLETED
- CORRECTED
- READY_TO_EXPORT
- EXPORTED
- EXPORTED_DOMAIN
- READY_TO_TRANSMIT
- TRANSMITTED
- READY_TO_RECTIFY
- RECTIFICATION_REQUESTED
- COMPLETED
- DELETED
- FAILED

Mapeamento com status legados já usados no sistema:

- IMPORTADO -> IMPORTED
- AUDITORIA FISCAL PARCIAL -> AUDIT_PARTIAL
- AUDITORIA FISCAL CONCLUÍDA -> AUDIT_COMPLETED
- CORRIGIDO -> CORRECTED
- EXPORTADO -> EXPORTED
- EXPORTADO - DOMÍNIO -> EXPORTED_DOMAIN
- TRANSMITIDO -> TRANSMITTED
- RETIFICAR -> READY_TO_RECTIFY ou RECTIFICATION_REQUESTED
- PROCESSO CONCLUÍDO -> COMPLETED
- EXCLUÍDO -> DELETED

---

## 5. Fluxo Operacional Recomendado

### 5.1 Importação

1. Criar registro em sped.sped_files
2. Criar protocolo em sped.sped_jobs com RECEIVED
3. Criar etapas base em sped.sped_job_stages com status PENDING
4. Processar TXT linha a linha e inserir em sped.sped_records
5. Atualizar etapa de import para COMPLETED
6. Evoluir workflow para IMPORTED
7. Registrar evento em sped.sped_job_events

### 5.2 Auditoria

1. Iniciar etapa de auditoria (RUNNING)
2. Atribuir responsável da etapa em responsible_by_email
3. Persistir achados no stage_payload e/ou em módulo de auditoria dedicado
4. Concluir etapa com COMPLETED ou FAILED
5. Atualizar workflow para IN_AUDIT, AUDIT_PARTIAL ou AUDIT_COMPLETED
6. Registrar eventos por transição

### 5.3 Correção

1. Abrir etapa de correção
2. Responsável obrigatório por etapa (responsible_by_email)
3. Registrar alterações e métricas em stage_payload
4. Ao finalizar, workflow para CORRECTED
5. Registrar evento com before/after de status

### 5.4 Exportação e Transmissão

1. Validar pré-condições (auditoria e correções)
2. Gerar arquivo de saída
3. Atualizar workflow para READY_TO_EXPORT e EXPORTED
4. Preparar transmissão e atualizar para READY_TO_TRANSMIT
5. Confirmar envio e atualizar para TRANSMITTED ou FAILED
6. Registrar eventos em todas as transições

---

## 6. Responsabilidade por Etapa (Ponto Crítico)

Campo responsável direto na tabela de etapa:

- sped.sped_job_stages.responsible_by_email

Regras:

- Deve apontar para account.users.email
- Pode ser NULL apenas quando etapa ainda não foi atribuída
- Para etapas em RUNNING, recomendado exigir responsável preenchido
- Mudança de responsável deve gerar evento em sped_job_events

Consulta operacional esperada:

- etapas pendentes por responsável
- etapas em execução sem heartbeat recente
- gargalos por usuário, por tenant e por stage_code

---

## 7. Contratos de API Recomendados

Endpoints mínimos sugeridos:

- GET /v1/sped/jobs
- GET /v1/sped/jobs/:spedJobId
- GET /v1/sped/jobs/:spedJobId/stages
- GET /v1/sped/jobs/:spedJobId/events
- PATCH /v1/sped/job-stages/:spedJobStageId/assign
- PATCH /v1/sped/job-stages/:spedJobStageId/start
- PATCH /v1/sped/job-stages/:spedJobStageId/finish
- PATCH /v1/sped/jobs/:spedJobId/status
- POST /v1/sped/import
- POST /v1/sped/jobs/:spedJobId/export
- POST /v1/sped/jobs/:spedJobId/transmit

Boas práticas de payload:

- retornar sempre protocol_code
- retornar workflow_status + current_stage_code + progress_percent
- incluir responsible_by_email nas respostas de etapa
- incluir último evento resumido para renderização rápida de timeline

---

## 8. Regras de Transação e Concorrência

- Persistência de arquivo e registros em transação controlada por lote
- Transições de workflow devem ser atômicas
- Evento de timeline deve ser gravado na mesma transação da mudança de status
- Notificação ao usuário deve ser desacoplada da transação principal
- Falha de notificação não reverte processo fiscal principal

---

## 9. Observabilidade e Suporte

Registrar logs estruturados com:

- protocol_code
- sped_job_id
- sped_file_id
- tenant_id
- est_id
- stage_code
- responsible_by_email
- duração por etapa
- contagem de erros e warnings

Métricas recomendadas:

- tempo médio por etapa
- jobs por status
- fila de jobs em RECEIVED/IN_AUDIT
- taxa de falha por stage_code
- top gargalos por responsável

---

## 10. Segurança e Autorização

- validar acesso por tenant_id e contexto do usuário autenticado
- não expor dados de outro tenant
- atribuição de etapa deve respeitar RBAC
- alterações em status críticos (EXPORTED, TRANSMITTED, DELETED) devem exigir permissão específica

---

## 11. Checklist de Entrega Backend

- Criar repositórios e contratos do módulo SPED
- Implementar importador com validação hierárquica
- Implementar serviço de orquestração de job e etapas
- Implementar atribuição de responsible_by_email
- Implementar timeline de eventos por transição
- Expor endpoints de acompanhamento e operação
- Integrar com sistema de notificações em pontos críticos
- Documentar API no OpenAPI
- Cobrir com testes unitários e integração

---

## 12. Próximos Passos Técnicos

- Criar catálogo de stage_code e event_code para governança
- Criar view operacional de gargalo por responsável
- Criar módulo de auditoria fiscal por domínio (participantes, produtos, NCM, documentos)
- Definir política de retificação e versionamento de correções
