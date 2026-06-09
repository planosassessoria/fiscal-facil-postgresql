# Demanda Técnica — Sistema de Notificações do Fiscal Fácil

> **Destinatário**: Programador Lucas Cícero 
> **Componente base**: `src/components/layout/NotificationMenu.vue`  
> **Data**: Maio/2026

---

## 1. Visão Geral

Você irá implementar o sistema central de notificações do Fiscal Fácil. Ele será responsável por comunicar eventos relevantes do sistema para um ou múltiplos usuários em tempo real, com persistência no banco de dados e integração com o WebSocket já existente na aplicação (Socket.IO via `useConnectionSocketStore`).

O componente base `NotificationMenu.vue` já existe em produção com dados mock. Seu trabalho é conectá-lo à infraestrutura real.

---

## 2. Contexto da Arquitetura

A aplicação usa:

- **Vue 3 + `<script setup>`** — Composition API direta (padrão do projeto)
- **Pinia** — gerenciamento de estado
- **Socket.IO** — já há um `useConnectionSocketStore` que gerencia conexão autenticada via `accessToken`
- **PostgreSQL** — banco de dados (**scripts SQL devem ser aprovados pelo responsável antes de executar**)
- **RBAC multi-tenant** — escritórios contábeis têm seus próprios usuários e estabelecimentos

---

## 3. Tipos de Notificação

Criar um enum/constante `NOTIFICATION_TYPES` em `src/models/notification.js`. Este será o ponto único de verdade — backend e frontend usam os mesmos identificadores de tipo.

```javascript
// src/models/notification.js

export const NOTIFICATION_TYPES = {
  // Importações de arquivos fiscais
  IMPORT_SPED_FISCAL:      { icon: 'fas fa-file-import',             color: 'positive' },
  IMPORT_SPED_CONTRIB:     { icon: 'fas fa-file-import',             color: 'positive' },
  IMPORT_SPED_ECD:         { icon: 'fas fa-file-import',             color: 'positive' },
  IMPORT_NFE_NFCE:         { icon: 'fas fa-file-invoice',            color: 'positive' },
  IMPORT_CTE:              { icon: 'fas fa-truck',                   color: 'positive' },
  IMPORT_RELATORIO_SEFAZ:  { icon: 'fas fa-landmark',               color: 'positive' },
  IMPORT_FAILED:           { icon: 'fas fa-file-circle-xmark',       color: 'negative' },

  // Geração de relatórios
  REPORT_READY:            { icon: 'fas fa-file-chart-column',       color: 'info'     },
  REPORT_FAILED:           { icon: 'fas fa-file-circle-exclamation', color: 'negative' },

  // Certificados digitais
  CERTIFICATE_EXPIRING:    { icon: 'fas fa-id-card-clip',            color: 'warning'  },
  CERTIFICATE_EXPIRED:     { icon: 'fas fa-id-card-clip',            color: 'negative' },

  // Tarefas e orientações de equipe
  TASK_ASSIGNED:           { icon: 'fas fa-list-check',              color: 'primary'  },
  TEAM_MESSAGE:            { icon: 'fas fa-comment-dots',            color: 'secondary'},

  // Sistema
  SYSTEM_UPDATE:           { icon: 'fas fa-arrow-up-right-dots',     color: 'primary'  },
  GENERIC:                 { icon: 'fas fa-bell',                    color: 'grey'     },
}
```

> **Por que centralizar?** O backend envia `notif_type: 'IMPORT_NFE_NFCE'` e o frontend resolve automaticamente ícone e cor — sem `if/else` ou `switch` espalhados pelo componente.

> **Padrão de nomenclatura para novos tipos — `{CATEGORIA}_{ACAO}` em `UPPER_SNAKE_CASE`:**
>
> | Categoria | Prefixo | Exemplos |
> |---|---|---|
> | Importações | `IMPORT_` | `IMPORT_NFE_NFCE`, `IMPORT_CERTIFICADO_DIGITAL`, `IMPORT_SPED_FISCAL` |
> | Relatórios | `REPORT_` | `REPORT_READY`, `REPORT_FAILED` |
> | Certificados | `CERTIFICATE_` | `CERTIFICATE_EXPIRING`, `CERTIFICATE_EXPIRED` |
> | Tarefas | `TASK_` | `TASK_ASSIGNED`, `TASK_COMPLETED` |
> | Mensagens de equipe | `TEAM_` | `TEAM_MESSAGE` |
> | Sistema | `SYSTEM_` | `SYSTEM_UPDATE`, `SYSTEM_MAINTENANCE` |
>
> Ao adicionar um novo tipo: (1) incluir em `NOTIFICATION_TYPES` no frontend, (2) usar o mesmo identificador no backend. **Não há CHECK constraint no banco** — o tipo é livre para crescer sem migração.

---

## 4. Estrutura de Dados

### 4.1 Model Frontend (`src/models/notification.js`)

```javascript
export class Notification {
  constructor() {
    this.notificationId = null      // UUID do banco (notification_id)
    this.notifType      = 'GENERIC' // chave de NOTIFICATION_TYPES (notif_type)
    this.notifTitle     = ''        // notif_title
    this.notifMessage   = ''        // notif_message
    this.isRead         = false     // is_read
    this.createdAt      = null      // ISO string
    this.notifMetadata  = {}        // notif_metadata — dados livres, ex: { importJobId, nfeKey }
    this.notifActionUrl = null      // notif_action_url — rota interna, ex: '/relatorios/123'
  }

  get icon() {
    return NOTIFICATION_TYPES[this.notifType]?.icon ?? NOTIFICATION_TYPES.GENERIC.icon
  }

  get color() {
    return NOTIFICATION_TYPES[this.notifType]?.color ?? NOTIFICATION_TYPES.GENERIC.color
  }

  /**
   * Formata data relativa ("Há 5 minutos", "Há 2 horas", etc.)
   * Usar date-fns/formatDistanceToNow com locale pt-BR
   * ou utilitário existente em src/utils/date.js
   */
  get timeAgo() {
    // implementar com date-fns ou similar
  }

  static fromAPI(data) {
    const n             = new Notification()
    n.notificationId    = data.notificationId
    n.notifType         = data.notifType
    n.notifTitle        = data.notifTitle
    n.notifMessage      = data.notifMessage
    n.isRead            = data.isRead
    n.createdAt         = data.createdAt
    n.notifMetadata     = data.notifMetadata  ?? {}
    n.notifActionUrl    = data.notifActionUrl ?? null
    return n
  }
}
```

### 4.2 Tabelas no Banco — ⚠️ CONSULTAR RESPONSÁVEL ANTES DE CRIAR

Abaixo está a **proposta** de estrutura. Não executar nenhum script sem aprovação prévia.

> **Referências reais do banco (já confirmadas no schema):**
> - Usuários → `account.users` — PK: `email VARCHAR(320)` (não é UUID)
> - Vínculo usuário-tenant → `account.users_tenants(email, tenant_id)` — tabela pivot do multi-tenant
> - Tenants → `partner.tenants` — PK: `tenant_id UUID`, campo `account_type`: `OFFICE | ACCOUNTANT | COMPANY | INDIVIDUAL`
> - Estabelecimentos → `partner.establishments` — PK: `est_id UUID`
> - Trigger de timestamp → `public.fn_update_timestamp()` (já existe, usar em todos os `BEFORE UPDATE`)
> - Owner de todos os objetos → `dorcilio`

---

#### Escopos de envio (`notif_scope`)

O sistema precisa suportar os seguintes alvos de notificação. A coluna `notif_scope` define como o backend resolve os destinatários finais em `notification_recipients`:

| `notif_scope`    | Quem recebe                                               | Campos obrigatórios              |
|------------------|-----------------------------------------------------------|----------------------------------|
| `USER`           | Um usuário específico                                     | `target_user_email`              |
| `TENANT`         | Todos os usuários de um tenant (escritório ou empresa)    | `tenant_id`                      |
| `ESTABLISHMENT`  | Todos os usuários vinculados a um estabelecimento         | `tenant_id` + `est_id`           |
| `ACCOUNT_TYPE`   | Todos os usuários de um tipo de conta (ex: só escritórios)| `target_account_type`            |
| `BROADCAST`      | Todos os usuários ativos do sistema                       | *(nenhum campo de alvo)*         |

> **Como o backend expande o escopo em destinatários individuais (via `account.users_tenants`):**
> ```
> USER          → target_user_email
>               → INSERT 1 linha em notification_recipients
>
> TENANT        → SELECT email FROM account.users_tenants
>                 WHERE tenant_id = X AND is_active = true
>               → INSERT N linhas em notification_recipients
>
> ESTABLISHMENT → SELECT tenant_id FROM partner.tenants WHERE est_id = X
>               → SELECT email FROM account.users_tenants
>                 WHERE tenant_id IN (...) AND is_active = true
>               → INSERT N linhas em notification_recipients
>
> ACCOUNT_TYPE  → SELECT tenant_id FROM partner.tenants WHERE account_type = X
>               → SELECT email FROM account.users_tenants
>                 WHERE tenant_id IN (...) AND is_active = true
>               → INSERT N linhas em notification_recipients
>
> BROADCAST     → SELECT email FROM account.users (todos ativos)
>               → INSERT N linhas em notification_recipients
> ```

---

```sql
-- PROPOSTA — aguardando validação do responsável

-- Schema dedicado para notificações
CREATE SCHEMA IF NOT EXISTS notification;
ALTER SCHEMA notification OWNER TO dorcilio;

COMMENT ON SCHEMA notification IS
    'Schema de notificações do sistema. Gerencia alertas em tempo real e persistidos para usuários e tenants.';

-- Tabela principal de notificações
CREATE TABLE IF NOT EXISTS notification.notifications (
    -- Chaves e vínculos
    notification_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id            UUID,                    -- NULL em BROADCAST e ACCOUNT_TYPE
    est_id               UUID,                    -- NULL em BROADCAST, ACCOUNT_TYPE e TENANT
    created_by           VARCHAR(320),            -- NULL = gerado automaticamente pelo sistema

    -- Escopo e alvo
    notif_scope          VARCHAR(30)  NOT NULL DEFAULT 'TENANT',
    target_user_email    VARCHAR(320),            -- Preenchido quando notif_scope = 'USER'
    target_account_type  VARCHAR(30),             -- Preenchido quando notif_scope = 'ACCOUNT_TYPE'

    -- Dados obrigatórios
    notif_type           VARCHAR(60)  NOT NULL,   -- chave de NOTIFICATION_TYPES
    notif_title          VARCHAR(255) NOT NULL,
    notif_message        TEXT         NOT NULL,

    -- Dados opcionais
    notif_metadata       JSONB        NOT NULL DEFAULT '{}',
    notif_action_url     VARCHAR(500),
    expires_at           TIMESTAMPTZ,             -- NULL = não expira

    -- Timestamps
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT clock_timestamp(),

    -- Integridade referencial
    CONSTRAINT fk_notifications_tenant FOREIGN KEY (tenant_id)
        REFERENCES partner.tenants(tenant_id) ON DELETE CASCADE,
    CONSTRAINT fk_notifications_establishment FOREIGN KEY (est_id)
        REFERENCES partner.establishments(est_id) ON DELETE SET NULL,
    CONSTRAINT fk_notifications_created_by FOREIGN KEY (created_by)
        REFERENCES account.users(email) ON DELETE SET NULL,
    CONSTRAINT fk_notifications_target_user FOREIGN KEY (target_user_email)
        REFERENCES account.users(email) ON DELETE CASCADE,

    -- Domínio: escopos válidos (fechado — requer migração para adicionar)
    -- notif_type é aberto para extenso: sem CHECK constraint (ver orientação de nomenclatura no COMMENT abaixo)
    CONSTRAINT ck_notifications_scope CHECK (notif_scope IN (
        'USER', 'TENANT', 'ESTABLISHMENT', 'ACCOUNT_TYPE', 'BROADCAST'
    )),
    CONSTRAINT ck_notifications_account_type CHECK (
        target_account_type IS NULL OR
        target_account_type IN ('OFFICE', 'ACCOUNTANT', 'COMPANY', 'INDIVIDUAL')
    ),

    -- Consistência: cada escopo exige seus campos de alvo
    CONSTRAINT ck_scope_user_requires_email
        CHECK (notif_scope != 'USER' OR target_user_email IS NOT NULL),
    CONSTRAINT ck_scope_account_type_requires_type
        CHECK (notif_scope != 'ACCOUNT_TYPE' OR target_account_type IS NOT NULL),
    CONSTRAINT ck_scope_tenant_requires_tenant_id
        CHECK (notif_scope NOT IN ('TENANT', 'ESTABLISHMENT', 'USER') OR tenant_id IS NOT NULL),
    CONSTRAINT ck_scope_establishment_requires_est_id
        CHECK (notif_scope != 'ESTABLISHMENT' OR est_id IS NOT NULL)
);

ALTER TABLE notification.notifications OWNER TO dorcilio;

COMMENT ON TABLE  notification.notifications                       IS 'Notificações do sistema com suporte a múltiplos escopos de entrega (usuário, tenant, tipo de conta, broadcast).';
COMMENT ON COLUMN notification.notifications.notification_id      IS 'Identificador único da notificação (UUID).';
COMMENT ON COLUMN notification.notifications.tenant_id            IS 'Tenant relacionado. NULL nos escopos BROADCAST e ACCOUNT_TYPE.';
COMMENT ON COLUMN notification.notifications.est_id               IS 'Estabelecimento relacionado. Preenchido nos escopos ESTABLISHMENT e USER.';
COMMENT ON COLUMN notification.notifications.created_by           IS 'E-mail do usuário que gerou a notificação. NULL quando gerada pelo sistema.';
COMMENT ON COLUMN notification.notifications.notif_scope          IS 'Escopo de entrega: USER | TENANT | ESTABLISHMENT | ACCOUNT_TYPE | BROADCAST.';
COMMENT ON COLUMN notification.notifications.target_user_email    IS 'Destinatário único. Obrigatório quando notif_scope = USER.';
COMMENT ON COLUMN notification.notifications.target_account_type  IS 'Tipo de conta alvo. Obrigatório quando notif_scope = ACCOUNT_TYPE (ex: OFFICE, COMPANY).';
COMMENT ON COLUMN notification.notifications.notif_type           IS 'Tipo da notificação. Sem CHECK constraint — extensivel sem migração. Padrão de nomenclatura: {CATEGORIA}_{ACAO} em UPPER_SNAKE_CASE. Categorias atuais: IMPORT_, REPORT_, CERTIFICATE_, TASK_, TEAM_, SYSTEM_. Exemplos: IMPORT_NFE_NFCE, IMPORT_CERTIFICADO_DIGITAL, CERTIFICATE_EXPIRING. O ponto único de verdade é src/models/notification.js (NOTIFICATION_TYPES).';
COMMENT ON COLUMN notification.notifications.notif_title          IS 'Título resumido exibido no painel de notificações.';
COMMENT ON COLUMN notification.notifications.notif_message        IS 'Mensagem completa da notificação.';
COMMENT ON COLUMN notification.notifications.notif_metadata       IS 'Dados livres em JSON específicos por tipo (ex: { importJobId, nfeKey, reportId }).';
COMMENT ON COLUMN notification.notifications.notif_action_url     IS 'Rota interna opcional para navegação ao clicar (ex: /relatorios/123).';
COMMENT ON COLUMN notification.notifications.expires_at           IS 'Data de expiração. NULL indica sem expiração.';
COMMENT ON COLUMN notification.notifications.created_at           IS 'Timestamp de criação da notificação.';

-- Índices
CREATE INDEX idx_notifications_tenant_date   ON notification.notifications (tenant_id, created_at DESC) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_notifications_scope         ON notification.notifications (notif_scope, created_at DESC);
CREATE INDEX idx_notifications_account_type  ON notification.notifications (target_account_type) WHERE target_account_type IS NOT NULL;
CREATE INDEX idx_notifications_est           ON notification.notifications (est_id) WHERE est_id IS NOT NULL;
CREATE INDEX idx_notifications_expires       ON notification.notifications (expires_at) WHERE expires_at IS NOT NULL;


-- Tabela de destinatários (1 notificação → N usuários)
-- Populada pelo backend no momento da criação, após resolução do notif_scope
CREATE TABLE IF NOT EXISTS notification.notification_recipients (
    -- Chaves
    recipient_id    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID         NOT NULL,
    user_email      VARCHAR(320) NOT NULL,   -- FK para account.users(email)

    -- Estado
    is_read         BOOLEAN      NOT NULL DEFAULT FALSE,
    read_at         TIMESTAMPTZ,

    -- Timestamps
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT clock_timestamp(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT clock_timestamp(),

    -- Constraints
    CONSTRAINT uk_notification_recipients_notif_user UNIQUE (notification_id, user_email),
    CONSTRAINT fk_recipients_notification FOREIGN KEY (notification_id)
        REFERENCES notification.notifications(notification_id) ON DELETE CASCADE,
    CONSTRAINT fk_recipients_user FOREIGN KEY (user_email)
        REFERENCES account.users(email) ON DELETE CASCADE
);

ALTER TABLE notification.notification_recipients OWNER TO dorcilio;

COMMENT ON TABLE  notification.notification_recipients                  IS 'Destinatários individuais de cada notificação. Gerada pelo backend após resolução do notif_scope.';
COMMENT ON COLUMN notification.notification_recipients.recipient_id    IS 'Identificador único do vínculo destinatário-notificação (UUID).';
COMMENT ON COLUMN notification.notification_recipients.notification_id IS 'Notificação vinculada (FK para notification.notifications).';
COMMENT ON COLUMN notification.notification_recipients.user_email      IS 'E-mail do usuário destinatário (FK para account.users). Identificador natural do usuário no sistema.';
COMMENT ON COLUMN notification.notification_recipients.is_read         IS 'Indica se o usuário leu a notificação.';
COMMENT ON COLUMN notification.notification_recipients.read_at         IS 'Timestamp exato da leitura.';
COMMENT ON COLUMN notification.notification_recipients.created_at      IS 'Timestamp de criação do vínculo.';
COMMENT ON COLUMN notification.notification_recipients.updated_at      IS 'Timestamp da última atualização (ex: marcação de leitura).';

-- Índices
CREATE INDEX idx_notif_recipients_user_read ON notification.notification_recipients (user_email, is_read);
CREATE INDEX idx_notif_recipients_notif     ON notification.notification_recipients (notification_id);

-- Trigger de atualização automática de timestamp
CREATE TRIGGER tr_upd_notification_recipients
    BEFORE UPDATE ON notification.notification_recipients
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_timestamp();
```

> **Por que duas tabelas?** `notifications` armazena o conteúdo uma única vez independente de quantos destinatários existam. `notification_recipients` materializa quem recebeu e rastreia leitura individualmente — sem duplicar conteúdo. O `notif_scope` preserva a intenção original do envio para auditoria e reprocessamento.

**Pontos já confirmados no schema atual:**
- ✅ `account.users` — PK é `email VARCHAR(320)`, **não UUID**
- ✅ `account.users_tenants(email, tenant_id)` — pivot que resolve TENANT/ESTABLISHMENT/ACCOUNT_TYPE → usuários individuais
- ✅ `partner.tenants.account_type` — valores reais: `OFFICE`, `ACCOUNTANT`, `COMPANY`, `INDIVIDUAL`
- ✅ `partner.tenants` — PK é `tenant_id UUID`
- ✅ `partner.establishments` — PK é `est_id UUID`
- ✅ Trigger de timestamp → `public.fn_update_timestamp()`
- ✅ `clock_timestamp()` — padrão do projeto (não `NOW()`)
- ✅ Owner de todos os objetos → `dorcilio`

**Pontos ainda a confirmar com o responsável:**
- Soft-delete vs hard-delete nas notificações (adicionar `deleted_at TIMESTAMPTZ`?)
- Implementar `expires_at` + job de limpeza desde o início?
- Notificação `TEAM_MESSAGE`: quem pode enviar? Apenas tenants do tipo `OFFICE`?

---

## 5. Serviço Frontend (`src/services/notification-service.js`)

```javascript
import http from '@/plugins/http'

const BASE = '/v1/notifications'

export default {
  /**
   * Lista notificações do usuário logado com paginação.
   * @param {{ page?: number, limit?: number, unreadOnly?: boolean }} params
   */
  async list(params = {}) {
    const { data } = await http.get(BASE, { params })
    return data // { data: [], hasMore: boolean, total: number }
  },

  /**
   * Endpoint leve — retorna só o contador de não lidas.
   * Útil como fallback de polling quando o socket reconecta.
   */
  async getUnreadCount() {
    const { data } = await http.get(`${BASE}/unread-count`)
    return data.count
  },

  /**
   * Marca uma notificação específica ou todas como lidas.
   * @param {string|'all'} notificationId
   */
  async markAsRead(notificationId) {
    const url = notificationId === 'all'
      ? `${BASE}/read-all`
      : `${BASE}/${notificationId}/read`
    const { data } = await http.patch(url)
    return data
  },

  /** Remove uma notificação do destinatário (soft ou hard — alinhar com backend). */
  async remove(notificationId) {
    await http.delete(`${BASE}/${notificationId}`)
  },
}
```

---

## 6. Pinia Store (`src/stores/notification.js`)

Esta store é o coração da funcionalidade. O `NotificationMenu.vue` consome apenas ela.

```javascript
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import notificationService from '@/services/notification-service'
import { Notification } from '@/models/notification'
import { notifyInfo } from '@/plugins/notify'

export const useNotificationStore = defineStore('notification', () => {
  // ─── State ────────────────────────────────────────────────────────────
  const notifications = ref([])
  const loading       = ref(false)
  const loaded        = ref(false)  // carregado ao menos 1x nesta sessão?
  const page          = ref(1)
  const hasMore       = ref(true)

  // ─── Getters ──────────────────────────────────────────────────────────
  const unreadCount = computed(
    () => notifications.value.filter((n) => !n.isRead).length
  )

  // ─── Actions ──────────────────────────────────────────────────────────
  async function fetchInitial() {
    if (loading.value) return
    loading.value = true
    try {
      const response = await notificationService.list({ page: 1, limit: 20 })
      notifications.value = response.data.map(Notification.fromAPI)
      hasMore.value        = response.hasMore
      loaded.value         = true
      page.value           = 1
    } finally {
      loading.value = false
    }
  }

  async function fetchMore() {
    if (loading.value || !hasMore.value) return
    loading.value = true
    try {
      const nextPage = page.value + 1
      const response = await notificationService.list({ page: nextPage, limit: 20 })
      notifications.value.push(...response.data.map(Notification.fromAPI))
      hasMore.value = response.hasMore
      page.value    = nextPage
    } finally {
      loading.value = false
    }
  }

  async function markAsRead(notificationId) {
    await notificationService.markAsRead(notificationId)
    const n = notifications.value.find((n) => n.notificationId === notificationId)
    if (n) n.isRead = true
  }

  async function markAllAsRead() {
    await notificationService.markAsRead('all')
    notifications.value.forEach((n) => (n.isRead = true))
  }

  async function remove(notificationId) {
    await notificationService.remove(notificationId)
    notifications.value = notifications.value.filter((n) => n.notificationId !== notificationId)
  }

  /**
   * Chamado pelo listener do socket ao receber 'notification:new'.
   * Insere no topo da lista e exibe toast leve.
   */
  function receiveRealTime(rawNotification) {
    const n = Notification.fromAPI(rawNotification)
    notifications.value.unshift(n)
    notifyInfo(n.notifTitle)
  }

  return {
    notifications, loading, loaded, hasMore, unreadCount,
    fetchInitial, fetchMore,
    markAsRead, markAllAsRead, remove,
    receiveRealTime,
  }
})
```

---

## 7. Integração com WebSocket (Ponto Crítico — Badge em Tempo Real)

O listener deve ser registrado **uma única vez**, dentro do `setupSocketListeners()` que já existe em `src/stores/connection-socket.js`. O componente não deve saber da existência do socket.

```javascript
// ADICIONAR em setupSocketListeners() — src/stores/connection-socket.js

this.socket.on('notification:new', (payload) => {
  // Import lazy para evitar circular dependency entre stores
  import('./notification').then(({ useNotificationStore }) => {
    useNotificationStore().receiveRealTime(payload)
  })
})
```

**Evento que o backend deve emitir (alinhar com o time de backend):**

```javascript
// O servidor Socket.IO emite para a sala do usuário:
// ⚠️ Identificador do usuário no sistema é o e-mail (account.users PK = email)
socket.to(`user:${userEmail}`).emit('notification:new', {
  notificationId, notif_type, notif_title, notif_message,
  notif_metadata, notif_action_url, createdAt, isRead: false
})
```

Cada usuário logado entra na sala `user:{userEmail}` ao conectar no socket. O backend emite na sala do(s) destinatário(s) — sem precisar conhecer qual socket específico está ativo. Ao reconectar após queda, o `getUnreadCount()` do service serve como fallback para sincronizar o contador.

---

## 8. Atualização do `NotificationMenu.vue`

Migrar o componente de dados mock para a store. Usar `<script setup>` conforme padrão do projeto.

```vue
<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'
import { useNotificationStore } from '@/stores/notification'

defineOptions({ name: 'NotificationMenu' })

const router = useRouter()
const notificationStore = useNotificationStore()
const { notifications, unreadCount, loading, hasMore } = storeToRefs(notificationStore)

const detailDialog          = ref(false)
const selectedNotification  = ref(null)

onMounted(() => {
  if (!notificationStore.loaded) {
    notificationStore.fetchInitial()
  }
})

const viewNotification = (notification) => {
  notificationStore.markAsRead(notification.notificationId)

  if (notification.notifActionUrl) {
    router.push(notification.notifActionUrl) // navega direto para o recurso
  } else {
    selectedNotification.value = notification
    detailDialog.value = true
  }
}
</script>
```

### Adicionar "Carregar mais" no template

```vue
<!-- Após os itens de notificação, dentro do q-list -->
<q-item v-if="hasMore" class="text-center q-py-xs">
  <q-item-section>
    <q-btn
      flat dense no-caps size="sm"
      label="Carregar mais"
      :loading="loading"
      color="primary"
      @click="notificationStore.fetchMore()"
    />
  </q-item-section>
</q-item>
```

---

## 9. Fluxo Completo de uma Notificação em Tempo Real

```
[Backend: Job de importação SPED finaliza]
        ↓
[Backend: INSERT em notification.notifications
         (notif_scope='TENANT', tenant_id=X, notif_type='IMPORT_SPED_FISCAL', ...)]
        ↓
[Backend: Resolve destinatários via account.users_tenants WHERE tenant_id = X AND is_active = true]
        ↓
[Backend: INSERT em notification.notification_recipients (um registro por usuário)]
        ↓
[Backend: socket.to('user:lucas@fiscalfacil.com.br').emit('notification:new', payload)]
        ↓
[Frontend: connection-socket.js — listener 'notification:new' dispara]
        ↓
[notificationStore.receiveRealTime(payload) — insere no início do array]
        ↓
[unreadCount reativo sobe automaticamente (computed)]
        ↓
[Badge no NotificationMenu re-renderiza com novo número]
        ↓
[notifyInfo('Importação SPED Fiscal concluída!') — toast no canto]
```

---

## 10. Boas Práticas e Checklist

### Segurança
- [ ] `GET /v1/notifications` retorna **apenas** notificações onde `notification_recipients.user_email` = email do JWT
- [ ] `DELETE` e `PATCH /read` validam no backend que `notification_recipients.user_email` === email do JWT
- [ ] Endpoint de criação valida que o `notif_scope` é compatível com o perfil do solicitante (ex: `BROADCAST` e `ACCOUNT_TYPE` apenas para `root = true`)
- [ ] Campo `notif_metadata` (JSONB) não pode ser renderizado como HTML sem sanitização

### Performance
- [ ] Paginação obrigatória (`limit: 20`) — nunca buscar tudo de uma vez
- [ ] `GET /unread-count` é endpoint leve (só `COUNT(*)`) para fallback de polling
- [ ] Índices no banco já propostos na seção 4.2

### UX
- [ ] Badge mostra `99+` quando ultrapassa 99 (já implementado — manter)
- [ ] Toast `notifyInfo` ao receber notificação em tempo real (já na store)
- [ ] Estado vazio bem comunicado (já no componente base — manter)
- [ ] Notificações não lidas com fundo diferenciado (já no componente base — manter)
- [ ] Ao clicar em notificação com `actionUrl`, navegar para a rota e fechar o menu

### Arquitetura
- [ ] Tipos em `src/models/notification.js` — ponto único de verdade
- [ ] Lógica de negócio fica na **store** e no **service**, nunca no componente
- [ ] `NotificationMenu.vue` é "burro" — só exibe e delega para a store
- [ ] Listener do socket em `connection-socket.js` — **nunca** dentro do componente

### Extensibilidade
- [ ] Novo tipo = adicionar em `NOTIFICATION_TYPES` — nenhum outro código muda
- [ ] `metadata` (JSONB) permite dados específicos por tipo sem alterar schema
- [ ] `actionUrl` pode apontar para qualquer rota do sistema

---

## 11. O Que NÃO Fazer

- **Não** colocar lógica de socket dentro de `NotificationMenu.vue`
- **Não** usar `setInterval`/`setTimeout` polling enquanto socket estiver conectado
- **Não** armazenar notificações em `localStorage` — ficam apenas em memória (Pinia) e no banco
- **Não** executar SQL sem aprovação do responsável
- **Não** retornar notificações de outros usuários/tenants no endpoint — validar sempre pelo JWT

---

## 12. Ordem de Implementação Sugerida

**Backend (este repositório):**
1. **Alinhar com responsável** os pontos da seção 4.2 (banco, soft-delete, tópico Kafka para o serviço de socket)
2. Criar as tabelas no banco após aprovação
3. **Submeter proposta de módulo/permissões RBAC** para aprovação (seção 14.3) — aguardar resposta antes de continuar
4. Criar o contrato do repositório (`notification-repository-contract.js`)
5. Criar as queries SQL em `src/infrastructure/database/queries/notification/`
6. Adicionar métodos de resolução de e-mails no `UserRepositoryContract` + `UserRepository` (seção 13.3)
7. Criar o repositório (`notification-repository.js`)
8. Criar os use cases — `SendNotificationUseCase` + os 5 de HTTP + `CreateUserNotificationUseCase` (seções 13.4, 13.5 e 13.12)
9. Criar os controllers (seção 13.8)
10. Criar os schemas de validação e a rota; registrar no router (seções 13.8 e 13.9)
11. Registrar tudo no container DI `src/main/config/container.js` (seção 13.10)
12. Injetar `sendNotificationUseCase` nos use cases que disparam notificações (ex: `SaveNotaFiscalUseCase`)
13. **[Aguardar aprovação RBAC]** Implementar `authorizerService.authorize()` nos use cases indicados (seção 14.2)
14. Documentar todos os endpoints no `openapi.yaml` (seção 13.11)

**Frontend (repositório do dashboard):**
13. Criar `src/models/notification.js`
14. Criar `src/services/notification-service.js`
15. Criar `src/stores/notification.js`
16. Adicionar listener no `src/stores/connection-socket.js`
17. Atualizar `NotificationMenu.vue` — substituir mock pela store

**Validação:**
18. Testar fluxo completo: importação → banco → Kafka → serviço de socket → badge → toast

---

## 13. Implementação Backend — Padrão do Projeto

> Esta seção detalha a implementação dos endpoints REST seguindo rigorosamente os padrões de Arquitetura Limpa e SOLID deste repositório.
>
> O backend **não tem servidor Socket.IO** — o serviço de socket é separado. Este repositório só persiste no banco e publica no Kafka. Confirmar o tópico e o payload com o time responsável pelo serviço de socket.

### 13.1 Estrutura de Arquivos a Criar

```
src/
├── domain/
│   ├── contracts/infrastructure/repositories/
│   │   └── notification-repository-contract.js
│   └── use-cases/
│       ├── send-notification-use-case.js           ← uso interno (outros use cases chamam)
│       ├── find-notifications-use-case.js          ← GET /v1/notifications
│       ├── get-unread-count-use-case.js            ← GET /v1/notifications/unread-count
│       ├── mark-notification-read-use-case.js      ← PATCH /v1/notifications/:id/read
│       ├── mark-all-notifications-read-use-case.js ← PATCH /v1/notifications/read-all
│       └── remove-notification-use-case.js         ← DELETE /v1/notifications/:id
├── infrastructure/
│   ├── database/queries/notification/
│   │   ├── insert-notification.sql
│   │   ├── insert-notification-recipients-bulk.sql
│   │   ├── select-notifications-by-user.sql
│   │   ├── select-unread-count-by-user.sql
│   │   ├── select-recipient-exists.sql
│   │   ├── update-notification-read.sql
│   │   ├── update-all-notifications-read.sql
│   │   └── delete-notification-recipient.sql
│   ├── repositories/
│   │   └── notification-repository.js
│   └── web/
│       ├── controllers/
│       │   ├── find-notifications-controller.js
│       │   ├── get-unread-count-controller.js
│       │   ├── mark-notification-read-controller.js
│       │   ├── mark-all-notifications-read-controller.js
│       │   └── remove-notification-controller.js
│       ├── validation-schemas/
│       │   └── find-notifications-schema.js
│       └── routes/
│           └── notifications-route.js
```

---

### 13.2 Contrato do Repositório

```javascript
// src/domain/contracts/infrastructure/repositories/notification-repository-contract.js

export default class NotificationRepositoryContract {
  async create(data, tx)                                { throw new Error('Not implemented') }
  async createRecipientsBulk(notificationId, emails, tx){ throw new Error('Not implemented') }
  async findByUser(userEmail, options)                  { throw new Error('Not implemented') }
  async getUnreadCount(userEmail)                       { throw new Error('Not implemented') }
  async recipientExists(notificationId, userEmail)      { throw new Error('Not implemented') }
  async markAsRead(notificationId, userEmail, tx)       { throw new Error('Not implemented') }
  async markAllAsRead(userEmail, tx)                    { throw new Error('Not implemented') }
  async removeRecipient(notificationId, userEmail, tx)  { throw new Error('Not implemented') }
}
```

---

### 13.3 Novos Métodos no `UserRepositoryContract` + `UserRepository`

O `SendNotificationUseCase` precisa resolver e-mails por escopo. Adicionar ao contrato existente e implementar com queries SQL nomeadas:

```javascript
// Adicionar em src/domain/contracts/infrastructure/repositories/user-repository-contract.js
async findEmailsByTenantId(tenantId)          { throw new Error('Not implemented') }
async findEmailsByEstId(estId)               { throw new Error('Not implemented') }
async findEmailsByAccountType(accountType)   { throw new Error('Not implemented') }
async findAllActiveEmails()                  { throw new Error('Not implemented') }
```

Queries SQL correspondentes (criar em `src/infrastructure/database/queries/account/`):

```sql
-- select-emails-by-tenant-id.sql — $1 = tenant_id
SELECT email FROM account.users_tenants
WHERE tenant_id = $1 AND is_active = TRUE;

-- select-emails-by-est-id.sql — $1 = est_id
-- Resolve todos os tenants do estabelecimento, depois os usuários de cada tenant
SELECT DISTINCT ut.email
FROM partner.tax_entities te
JOIN account.users_tenants ut ON ut.tenant_id = te.tenant_id
WHERE te.est_id = $1 AND ut.is_active = TRUE;

-- select-emails-by-account-type.sql — $1 = account_type
SELECT DISTINCT ut.email
FROM partner.tenants t
JOIN account.users_tenants ut ON ut.tenant_id = t.tenant_id
WHERE t.account_type = $1 AND ut.is_active = TRUE;

-- select-all-active-emails.sql — sem parâmetros
SELECT email FROM account.users WHERE email_confirmed = TRUE;
```

---

### 13.4 Use Case Interno — `SendNotificationUseCase`

Chamado por outros use cases ao final de um processo — **não exposto via HTTP**.

```javascript
// src/domain/use-cases/send-notification-use-case.js
import { DomainValidationError } from '../errors/index.js'

export class SendNotificationUseCase {
  /**
   * @param {Object} deps
   * @param {import('../contracts/infrastructure/repositories/notification-repository-contract.js').default} deps.notificationRepository
   * @param {import('../contracts/infrastructure/repositories/user-repository-contract.js').default} deps.userRepository
   * @param {Object} deps.kafkaProducer
   * @param {Object} deps.dbConnection
   * @param {Object} deps.logger
   */
  constructor({ notificationRepository, userRepository, kafkaProducer, dbConnection, logger }) {
    this._notificationRepository = notificationRepository
    this._userRepository         = userRepository
    this._kafkaProducer          = kafkaProducer
    this._dbConnection           = dbConnection
    this._logger                 = logger
  }

  /**
   * Persiste a notificação + destinatários e publica no Kafka para o serviço de socket.
   *
   * @param {Object} data
   * @param {string}  data.notifScope          - 'USER' | 'TENANT' | 'ESTABLISHMENT' | 'ACCOUNT_TYPE' | 'BROADCAST'
   * @param {string}  data.notifType           - Chave de NOTIFICATION_TYPES
   * @param {string}  data.notifTitle          - Título
   * @param {string}  data.notifMessage        - Mensagem completa
   * @param {string}  [data.tenantId]          - Obrigatório para TENANT, ESTABLISHMENT, USER
   * @param {string}  [data.estId]             - Obrigatório para ESTABLISHMENT
   * @param {string}  [data.targetUserEmail]   - Obrigatório para USER
   * @param {string}  [data.targetAccountType] - Obrigatório para ACCOUNT_TYPE
   * @param {string}  [data.createdBy]         - Email do autor (null = sistema)
   * @param {Object}  [data.notifMetadata]     - Dados livres específicos do tipo
   * @param {string}  [data.notifActionUrl]    - Rota interna opcional
   * @param {Object}  [externalTx]             - Transação externa para atomicidade com o processo pai
   * @returns {Promise<{ notificationId: string, recipientCount: number }>}
   */
  async execute(data, externalTx = null) {
    const tx = externalTx || await this._dbConnection.startTransaction()

    try {
      const notification = await this._notificationRepository.create(data, tx)
      const emails       = await this.#resolveRecipients(data)

      if (emails.length > 0) {
        await this._notificationRepository.createRecipientsBulk(
          notification.notificationId,
          emails,
          tx
        )
      } else {
        this._logger.warn('SendNotificationUseCase: nenhum destinatário resolvido', {
          notifScope: data.notifScope,
          tenantId: data.tenantId,
        })
      }

      if (!externalTx) await tx.commit()

      // Publica no Kafka APÓS o commit — falha aqui não reverte a persistência
      // ⚠️ Confirmar nome do tópico e payload exato com o time do serviço de socket
      await this.#publishToSocket(notification, emails)

      this._logger.info('Notificação criada', {
        notificationId: notification.notificationId,
        notifScope: data.notifScope,
        recipientCount: emails.length,
      })

      return { notificationId: notification.notificationId, recipientCount: emails.length }
    } catch (error) {
      if (!externalTx) await tx.rollback()
      this._logger.error('Erro ao criar notificação', { error: error.message })
      throw error
    }
  }

  async #resolveRecipients(data) {
    switch (data.notifScope) {
      case 'USER':
        return [data.targetUserEmail]
      case 'TENANT':
        return this._userRepository.findEmailsByTenantId(data.tenantId)
      case 'ESTABLISHMENT':
        return this._userRepository.findEmailsByEstId(data.estId)
      case 'ACCOUNT_TYPE':
        return this._userRepository.findEmailsByAccountType(data.targetAccountType)
      case 'BROADCAST':
        return this._userRepository.findAllActiveEmails()
      default:
        throw new DomainValidationError(`notif_scope inválido: ${data.notifScope}`)
    }
  }

  async #publishToSocket(notification, recipientEmails) {
    try {
      await this._kafkaProducer.send('notifications.dispatch', {
        notificationId: notification.notificationId,
        recipientEmails,
        notifType:      notification.notifType,
        notifTitle:     notification.notifTitle,
        notifMessage:   notification.notifMessage,
        notifMetadata:  notification.notifMetadata ?? {},
        notifActionUrl: notification.notifActionUrl ?? null,
        createdAt:      notification.createdAt,
      })
    } catch (kafkaError) {
      // Kafka indisponível não deve derrubar o fluxo — notificação já está no banco
      this._logger.error('Falha ao publicar notificação no Kafka', { error: kafkaError.message })
    }
  }
}

export default SendNotificationUseCase
```

**Como chamar em outro use case** (ex: ao final de uma importação):

```javascript
// Dentro de SaveNotaFiscalUseCase ou similar, após tx.commit() do processo principal:
try {
  await this._sendNotificationUseCase.execute({
    notifScope:     'TENANT',
    tenantId:       job.tenantId,
    notifType:      'IMPORT_NFE_NFCE',
    notifTitle:     'Importação NF-e concluída',
    notifMessage:   `${job.totalCount} notas importadas com sucesso.`,
    notifMetadata:  { importJobId: job.jobId },
    notifActionUrl: `/nfe/jobs/${job.jobId}`,
    createdBy:      null, // gerado pelo sistema
  })
  // Sem tx externo — notificação tem sua própria transação isolada
} catch (notifError) {
  // ⚠️ REGRA: falha na notificação NUNCA deve reverter o processo pai
  this._logger.error('Falha ao enviar notificação', { error: notifError.message })
}
```

> Para injetar `sendNotificationUseCase` nos use cases existentes: adicionar `sendNotificationUseCase` no construtor via desestruturação, seguindo o padrão DIP do projeto.

---

### 13.5 Use Cases dos Endpoints HTTP

#### `FindNotificationsUseCase`

```javascript
// src/domain/use-cases/find-notifications-use-case.js

export class FindNotificationsUseCase {
  /**
   * @param {Object} deps
   * @param {import('../contracts/infrastructure/repositories/notification-repository-contract.js').default} deps.notificationRepository
   * @param {import('../services/pagination-service.js').default} deps.paginationService
   */
  constructor({ notificationRepository, paginationService }) {
    this._notificationRepository = notificationRepository
    this._paginationService      = paginationService
  }

  static ALLOWED_SORT_FIELDS = ['created_at', 'is_read']
  static DEFAULT_SORT        = 'created_at'

  async execute(sessionUser, queryParams = {}) {
    // Mapeia 'limit' (Pinia store) → 'rowsPerPage' (PaginationService)
    const params = { ...queryParams }
    if (params.limit && !params.rowsPerPage) {
      params.rowsPerPage = params.limit
      delete params.limit
    }

    const { limit, offset, orderBy, orderDirection, page } =
      this._paginationService.getParams(
        params,
        FindNotificationsUseCase.ALLOWED_SORT_FIELDS,
        FindNotificationsUseCase.DEFAULT_SORT
      )

    const rows  = await this._notificationRepository.findByUser(
      sessionUser.email,
      { limit, offset, orderBy, orderDirection }
    )

    const total   = rows[0]?.rowsNumber ?? 0
    const hasMore = offset + rows.length < total

    return { data: rows, hasMore, total, page }
  }
}

export default FindNotificationsUseCase
```

#### `GetUnreadCountUseCase`

```javascript
// src/domain/use-cases/get-unread-count-use-case.js

export class GetUnreadCountUseCase {
  constructor({ notificationRepository }) {
    this._notificationRepository = notificationRepository
  }

  async execute(sessionUser) {
    const count = await this._notificationRepository.getUnreadCount(sessionUser.email)
    return { count }
  }
}

export default GetUnreadCountUseCase
```

#### `MarkNotificationReadUseCase`

```javascript
// src/domain/use-cases/mark-notification-read-use-case.js
import { ForbiddenError } from '../errors/index.js'

export class MarkNotificationReadUseCase {
  constructor({ notificationRepository, dbConnection }) {
    this._notificationRepository = notificationRepository
    this._dbConnection           = dbConnection
  }

  async execute(sessionUser, notificationId) {
    const exists = await this._notificationRepository.recipientExists(
      notificationId,
      sessionUser.email
    )
    if (!exists) throw new ForbiddenError('Notificação não encontrada ou sem permissão')

    const tx = await this._dbConnection.startTransaction()
    try {
      await this._notificationRepository.markAsRead(notificationId, sessionUser.email, tx)
      await tx.commit()
      return { success: true }
    } catch (error) {
      await tx.rollback()
      throw error
    }
  }
}

export default MarkNotificationReadUseCase
```

#### `MarkAllNotificationsReadUseCase`

```javascript
// src/domain/use-cases/mark-all-notifications-read-use-case.js

export class MarkAllNotificationsReadUseCase {
  constructor({ notificationRepository, dbConnection }) {
    this._notificationRepository = notificationRepository
    this._dbConnection           = dbConnection
  }

  async execute(sessionUser) {
    const tx = await this._dbConnection.startTransaction()
    try {
      await this._notificationRepository.markAllAsRead(sessionUser.email, tx)
      await tx.commit()
      return { success: true }
    } catch (error) {
      await tx.rollback()
      throw error
    }
  }
}

export default MarkAllNotificationsReadUseCase
```

#### `RemoveNotificationUseCase`

```javascript
// src/domain/use-cases/remove-notification-use-case.js
import { ForbiddenError } from '../errors/index.js'

export class RemoveNotificationUseCase {
  constructor({ notificationRepository, dbConnection }) {
    this._notificationRepository = notificationRepository
    this._dbConnection           = dbConnection
  }

  async execute(sessionUser, notificationId) {
    const exists = await this._notificationRepository.recipientExists(
      notificationId,
      sessionUser.email
    )
    if (!exists) throw new ForbiddenError('Notificação não encontrada ou sem permissão')

    const tx = await this._dbConnection.startTransaction()
    try {
      await this._notificationRepository.removeRecipient(notificationId, sessionUser.email, tx)
      await tx.commit()
      return { success: true }
    } catch (error) {
      await tx.rollback()
      throw error
    }
  }
}

export default RemoveNotificationUseCase
```

---

### 13.6 Repositório

```javascript
// src/infrastructure/repositories/notification-repository.js
import format from 'pg-format'
import NotificationRepositoryContract from '../../domain/contracts/infrastructure/repositories/notification-repository-contract.js'

export class NotificationRepository extends NotificationRepositoryContract {
  constructor({ dbConnection, repositoryQueryManager, databaseResultMapper, logger }) {
    super()
    this._dbConnection            = dbConnection
    this._repositoryQueryManager  = repositoryQueryManager
    this._databaseResultMapper    = databaseResultMapper
    this._logger                  = logger
    this._ready                   = this.#initializeQueries()
  }

  async #initializeQueries() {
    try {
      const queries = [
        { name: 'insertNotification',           path: '/notification/insert-notification.sql' },
        { name: 'insertRecipientsBulk',         path: '/notification/insert-notification-recipients-bulk.sql' },
        { name: 'selectNotificationsByUser',    path: '/notification/select-notifications-by-user.sql' },
        { name: 'selectUnreadCountByUser',      path: '/notification/select-unread-count-by-user.sql' },
        { name: 'selectRecipientExists',        path: '/notification/select-recipient-exists.sql' },
        { name: 'updateNotificationRead',       path: '/notification/update-notification-read.sql' },
        { name: 'updateAllNotificationsRead',   path: '/notification/update-all-notifications-read.sql' },
        { name: 'deleteNotificationRecipient',  path: '/notification/delete-notification-recipient.sql' },
      ]
      for (const q of queries) {
        await this._repositoryQueryManager.loadNamedQuery(q.name, q.path)
      }
      this._logger?.debug('Queries do NotificationRepository carregadas')
    } catch (error) {
      this._logger?.error('Erro ao carregar queries do NotificationRepository', error)
      throw error
    }
  }

  async create(data, tx = null) {
    await this._ready
    const executor = tx || this._dbConnection
    try {
      const query  = this._repositoryQueryManager.getQuery('insertNotification')
      const params = [
        data.tenantId           ?? null,
        data.estId              ?? null,
        data.createdBy          ?? null,
        data.notifScope,
        data.targetUserEmail    ?? null,
        data.targetAccountType  ?? null,
        data.notifType,
        data.notifTitle,
        data.notifMessage,
        JSON.stringify(data.notifMetadata ?? {}),
        data.notifActionUrl     ?? null,
        data.expiresAt          ?? null,
      ]
      const result = await executor.executeQuery(query, params)
      return this._databaseResultMapper.mapOne(result.rows[0])
    } catch (error) {
      this._logger?.error('Erro ao criar notificação', { error: error.message })
      throw error
    }
  }

  async createRecipientsBulk(notificationId, emails, tx = null) {
    await this._ready
    const executor = tx || this._dbConnection
    try {
      const baseQuery = this._repositoryQueryManager.getQuery('insertRecipientsBulk')
      const values    = emails.map((email) => [notificationId, email])
      const query     = format(baseQuery, values) // pg-format monta VALUES seguro
      const result    = await executor.executeQuery(query, [])
      return result.rowCount
    } catch (error) {
      this._logger?.error('Erro ao criar recipients em bulk', { error: error.message })
      throw error
    }
  }

  async findByUser(userEmail, options = {}) {
    await this._ready
    try {
      const query  = this._repositoryQueryManager.getQuery('selectNotificationsByUser')
      const result = await this._dbConnection.executeQuery(query, [
        userEmail,
        options.limit  ?? 20,
        options.offset ?? 0,
      ])
      return this._databaseResultMapper.mapList(result.rows)
    } catch (error) {
      this._logger?.error('Erro ao buscar notificações', { error: error.message })
      throw error
    }
  }

  async getUnreadCount(userEmail) {
    await this._ready
    try {
      const query  = this._repositoryQueryManager.getQuery('selectUnreadCountByUser')
      const result = await this._dbConnection.executeQuery(query, [userEmail])
      return parseInt(result.rows[0]?.count ?? 0, 10)
    } catch (error) {
      this._logger?.error('Erro ao buscar contagem de não lidas', { error: error.message })
      throw error
    }
  }

  async recipientExists(notificationId, userEmail) {
    await this._ready
    try {
      const query  = this._repositoryQueryManager.getQuery('selectRecipientExists')
      const result = await this._dbConnection.executeQuery(query, [notificationId, userEmail])
      return result.rows[0]?.exists === true
    } catch (error) {
      this._logger?.error('Erro ao verificar posse de notificação', { error: error.message })
      throw error
    }
  }

  async markAsRead(notificationId, userEmail, tx = null) {
    await this._ready
    const executor = tx || this._dbConnection
    try {
      const query = this._repositoryQueryManager.getQuery('updateNotificationRead')
      await executor.executeQuery(query, [notificationId, userEmail])
    } catch (error) {
      this._logger?.error('Erro ao marcar como lida', { error: error.message })
      throw error
    }
  }

  async markAllAsRead(userEmail, tx = null) {
    await this._ready
    const executor = tx || this._dbConnection
    try {
      const query = this._repositoryQueryManager.getQuery('updateAllNotificationsRead')
      await executor.executeQuery(query, [userEmail])
    } catch (error) {
      this._logger?.error('Erro ao marcar todas como lidas', { error: error.message })
      throw error
    }
  }

  async removeRecipient(notificationId, userEmail, tx = null) {
    await this._ready
    const executor = tx || this._dbConnection
    try {
      const query = this._repositoryQueryManager.getQuery('deleteNotificationRecipient')
      await executor.executeQuery(query, [notificationId, userEmail])
    } catch (error) {
      this._logger?.error('Erro ao remover notificação', { error: error.message })
      throw error
    }
  }
}

export default NotificationRepository
```

---

### 13.7 Queries SQL

Criar a pasta `src/infrastructure/database/queries/notification/` e os arquivos abaixo. Seguir o padrão de comentários do projeto (cabeçalho com parâmetros documentados).

```sql
-- insert-notification.sql
-- $1=tenant_id $2=est_id $3=created_by $4=notif_scope $5=target_user_email
-- $6=target_account_type $7=notif_type $8=notif_title $9=notif_message
-- $10=notif_metadata $11=notif_action_url $12=expires_at
INSERT INTO notification.notifications (
  tenant_id, est_id, created_by, notif_scope,
  target_user_email, target_account_type,
  notif_type, notif_title, notif_message,
  notif_metadata, notif_action_url, expires_at
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11, $12)
RETURNING notification_id, notif_type, notif_title, notif_message,
          notif_scope, notif_metadata, notif_action_url, created_at;
```

```sql
-- insert-notification-recipients-bulk.sql
-- Parâmetro montado via pg-format: VALUES %L → [notification_id, user_email][]
INSERT INTO notification.notification_recipients (notification_id, user_email)
VALUES %L
ON CONFLICT (notification_id, user_email) DO NOTHING;
```

```sql
-- select-notifications-by-user.sql
-- $1=user_email  $2=limit  $3=offset
SELECT
  n.notification_id,
  n.notif_type,
  n.notif_title,
  n.notif_message,
  n.notif_metadata,
  n.notif_action_url,
  n.created_at,
  nr.is_read,
  nr.read_at,
  COUNT(*) OVER () AS rows_number
FROM notification.notification_recipients nr
JOIN notification.notifications n ON n.notification_id = nr.notification_id
WHERE nr.user_email = $1
ORDER BY n.created_at DESC
LIMIT $2 OFFSET $3;
```

```sql
-- select-unread-count-by-user.sql
-- $1=user_email
SELECT COUNT(*)::INT AS count
FROM notification.notification_recipients
WHERE user_email = $1 AND is_read = FALSE;
```

```sql
-- select-recipient-exists.sql
-- $1=notification_id  $2=user_email
SELECT EXISTS (
  SELECT 1 FROM notification.notification_recipients
  WHERE notification_id = $1 AND user_email = $2
) AS exists;
```

```sql
-- update-notification-read.sql
-- $1=notification_id  $2=user_email
UPDATE notification.notification_recipients
SET is_read = TRUE, read_at = clock_timestamp()
WHERE notification_id = $1 AND user_email = $2;
```

```sql
-- update-all-notifications-read.sql
-- $1=user_email
UPDATE notification.notification_recipients
SET is_read = TRUE, read_at = clock_timestamp()
WHERE user_email = $1 AND is_read = FALSE;
```

```sql
-- delete-notification-recipient.sql
-- $1=notification_id  $2=user_email
DELETE FROM notification.notification_recipients
WHERE notification_id = $1 AND user_email = $2;
```

---

### 13.8 Controllers e Validation Schema

Todos os controllers seguem o mesmo padrão SRP do projeto:

```javascript
// Padrão idêntico para todos — variar apenas o use case injetado
// Exemplo: find-notifications-controller.js
export class FindNotificationsController {
  constructor({ findNotificationsUseCase, httpResponse, logger }) {
    this._findNotificationsUseCase = findNotificationsUseCase
    this._httpResponse             = httpResponse
    this._logger                   = logger
  }

  async handle(req, res) {
    try {
      const result = await this._findNotificationsUseCase.execute(req.user, req.query)
      return this._httpResponse.ok(res, result)
    } catch (error) {
      this._logger?.error('Erro ao listar notificações', { error: error.message })
      return this._httpResponse.customError(res, error.statusCode || 500, error)
    }
  }
}
export default FindNotificationsController
```

```javascript
// src/infrastructure/web/validation-schemas/find-notifications-schema.js
import Joi from 'joi'

export const findNotificationsSchema = Joi.object({
  page:        Joi.number().integer().min(1).default(1),
  rowsPerPage: Joi.number().integer().min(1).max(50).default(20),
  limit:       Joi.number().integer().min(1).max(50), // alias enviado pela store
}).options({ stripUnknown: true })
```

---

### 13.9 Rota

```javascript
// src/infrastructure/web/routes/notifications-route.js
import { makeInvoker } from 'awilix-express'
import { Router } from 'express'
import { findNotificationsSchema } from '../validation-schemas/find-notifications-schema.js'

const _router = Router()

const listApi        = makeInvoker(({ findNotificationsController })        => findNotificationsController)
const unreadCountApi = makeInvoker(({ getUnreadCountController })           => getUnreadCountController)
const markReadApi    = makeInvoker(({ markNotificationReadController })     => markNotificationReadController)
const markAllApi     = makeInvoker(({ markAllNotificationsReadController }) => markAllNotificationsReadController)
const removeApi      = makeInvoker(({ removeNotificationController })       => removeNotificationController)

export default function createNotificationsRoute({ authRequestMiddleware, validationRequestMiddleware }) {
  _router.get(
    '/',
    authRequestMiddleware.auth,
    validationRequestMiddleware.validate(findNotificationsSchema),
    listApi('handle')
  )

  _router.get(
    '/unread-count',
    authRequestMiddleware.auth,
    unreadCountApi('handle')
  )

  // ⚠️ /read-all DEVE vir antes de /:notificationId para o Express não confundir as rotas
  _router.patch(
    '/read-all',
    authRequestMiddleware.auth,
    markAllApi('handle')
  )

  _router.patch(
    '/:notificationId/read',
    authRequestMiddleware.auth,
    markReadApi('handle')
  )

  _router.delete(
    '/:notificationId',
    authRequestMiddleware.auth,
    removeApi('handle')
  )

  return _router
}
```

Registrar no router principal (`src/infrastructure/web/routes/index.js`):

```javascript
import notificationsRoute from './notifications-route.js'

// Dentro de createRouter():
_router.use('/notifications', notificationsRoute({ authRequestMiddleware, validationRequestMiddleware }))
```

---

### 13.10 Registro no Container DI

Adicionar em `src/main/config/container.js` nas seções correspondentes (imports e `container.register`):

```javascript
// Imports — adicionar junto com os demais
import NotificationRepository              from '../../infrastructure/repositories/notification-repository.js'
import SendNotificationUseCase             from '../../domain/use-cases/send-notification-use-case.js'
import FindNotificationsUseCase            from '../../domain/use-cases/find-notifications-use-case.js'
import GetUnreadCountUseCase               from '../../domain/use-cases/get-unread-count-use-case.js'
import MarkNotificationReadUseCase         from '../../domain/use-cases/mark-notification-read-use-case.js'
import MarkAllNotificationsReadUseCase     from '../../domain/use-cases/mark-all-notifications-read-use-case.js'
import RemoveNotificationUseCase           from '../../domain/use-cases/remove-notification-use-case.js'
import FindNotificationsController         from '../../infrastructure/web/controllers/find-notifications-controller.js'
import GetUnreadCountController            from '../../infrastructure/web/controllers/get-unread-count-controller.js'
import MarkNotificationReadController      from '../../infrastructure/web/controllers/mark-notification-read-controller.js'
import MarkAllNotificationsReadController  from '../../infrastructure/web/controllers/mark-all-notifications-read-controller.js'
import RemoveNotificationController        from '../../infrastructure/web/controllers/remove-notification-controller.js'

// Registros — adicionar em container.register()
notificationRepository: asClass(NotificationRepository).singleton()
  .inject(() => ({
    repositoryQueryManager: container.resolve('repositoryQueryManagerFactory').create(),
  })),

sendNotificationUseCase:            asClass(SendNotificationUseCase).singleton(),
findNotificationsUseCase:           asClass(FindNotificationsUseCase).singleton(),
getUnreadCountUseCase:              asClass(GetUnreadCountUseCase).singleton(),
markNotificationReadUseCase:        asClass(MarkNotificationReadUseCase).singleton(),
markAllNotificationsReadUseCase:    asClass(MarkAllNotificationsReadUseCase).singleton(),
removeNotificationUseCase:          asClass(RemoveNotificationUseCase).singleton(),

findNotificationsController:        asClass(FindNotificationsController).singleton(),
getUnreadCountController:           asClass(GetUnreadCountController).singleton(),
markNotificationReadController:     asClass(MarkNotificationReadController).singleton(),
markAllNotificationsReadController: asClass(MarkAllNotificationsReadController).singleton(),
removeNotificationController:       asClass(RemoveNotificationController).singleton(),
```

---

### 13.11 Documentação Swagger (`openapi.yaml`)

Adicionar a tag e os 5 paths em `src/infrastructure/web/docs/openapi.yaml`:

```yaml
# Em tags[]:
- name: Notifications
  description: Notificações do usuário autenticado

# Em paths:

/notifications:
  get:
    tags: [Notifications]
    summary: Lista notificações do usuário autenticado com paginação
    operationId: findNotifications
    security:
      - BearerAuth: []
    parameters:
      - in: query
        name: page
        schema: { type: integer, default: 1 }
      - in: query
        name: limit
        schema: { type: integer, default: 20, maximum: 50 }
    responses:
      '200':
        description: Lista paginada de notificações
        content:
          application/json:
            schema:
              type: object
              properties:
                data:
                  type: array
                  items:
                    $ref: '#/components/schemas/NotificationItem'
                hasMore:  { type: boolean }
                total:    { type: integer }
                page:     { type: integer }
      '401': { $ref: '#/components/responses/Unauthorized' }

/notifications/unread-count:
  get:
    tags: [Notifications]
    summary: Retorna o total de notificações não lidas
    operationId: getUnreadCount
    security:
      - BearerAuth: []
    responses:
      '200':
        description: Contador de não lidas
        content:
          application/json:
            schema:
              type: object
              properties:
                count: { type: integer, example: 3 }
      '401': { $ref: '#/components/responses/Unauthorized' }

/notifications/read-all:
  patch:
    tags: [Notifications]
    summary: Marca todas as notificações do usuário como lidas
    operationId: markAllNotificationsRead
    security:
      - BearerAuth: []
    responses:
      '200':
        description: Todas as notificações marcadas como lidas
      '401': { $ref: '#/components/responses/Unauthorized' }

/notifications/{notificationId}/read:
  patch:
    tags: [Notifications]
    summary: Marca uma notificação específica como lida
    operationId: markNotificationRead
    security:
      - BearerAuth: []
    parameters:
      - in: path
        name: notificationId
        required: true
        schema: { type: string, format: uuid }
    responses:
      '200':
        description: Notificação marcada como lida
      '401': { $ref: '#/components/responses/Unauthorized' }
      '403':
        description: Notificação não pertence ao usuário autenticado
      '500': { $ref: '#/components/responses/InternalServerError' }

/notifications/{notificationId}:
  delete:
    tags: [Notifications]
    summary: Remove uma notificação da lista do usuário
    operationId: removeNotification
    security:
      - BearerAuth: []
    parameters:
      - in: path
        name: notificationId
        required: true
        schema: { type: string, format: uuid }
    responses:
      '200':
        description: Notificação removida
      '401': { $ref: '#/components/responses/Unauthorized' }
      '403':
        description: Notificação não pertence ao usuário autenticado
      '500': { $ref: '#/components/responses/InternalServerError' }
```

Schema reutilizável (adicionar em `components.schemas`):

```yaml
NotificationItem:
  type: object
  properties:
    notificationId:  { type: string, format: uuid }
    notifType:       { type: string, example: IMPORT_NFE_NFCE }
    notifTitle:      { type: string, example: 'Importação NF-e concluída' }
    notifMessage:    { type: string }
    notifMetadata:   { type: object }
    notifActionUrl:  { type: string, nullable: true, example: '/nfe/jobs/abc-123' }
    isRead:          { type: boolean }
    readAt:          { type: string, format: date-time, nullable: true }
    createdAt:       { type: string, format: date-time }
```

---

### 13.12 Envio de Notificação por Usuário — Regras de Negócio Multi-Tenant

> O modelo de dados **já suporta** todos esses cenários — `notif_scope`, `created_by`, `target_user_email`, `est_id` e `tenant_id` cobrem todas as combinações. O que precisa ser construído é um use case com a lógica de autorização baseada no vínculo de carteira (`tax_entities`).

---

#### Matriz de Autorização

| Remetente (`accountType`) | Scope permitido | Alvo | Condição de autorização |
|---|---|---|---|
| `OFFICE` / `ACCOUNTANT` | `USER` | Usuário de tenant parceiro | Tenant do destinatário tem `est_id` na carteira do escritório (`tax_entities`) |
| `OFFICE` / `ACCOUNTANT` | `ESTABLISHMENT` | Todos vinculados a um estabelecimento parceiro | `est_id` do payload na carteira do escritório |
| `COMPANY` / `INDIVIDUAL` | `USER` | Usuário de um escritório parceiro | Tenant do destinatário tem o `est_id` do remetente na carteira |
| `COMPANY` / `INDIVIDUAL` | `ESTABLISHMENT` | Todos vinculados ao **próprio** estabelecimento | `est_id` deve ser o próprio `est_id` do tenant remetente — envia para todos escritórios da carteira |
| `ROOT` | `USER` | Qualquer usuário | Sem restrição |
| `ROOT` | `TENANT` | Todos usuários de qualquer tenant | Sem restrição |
| `ROOT` | `BROADCAST` | Todos os usuários ativos | Sem restrição |

> **Por que o ESTABLISHMENT scope é bidirecional?** A query de resolução do `SendNotificationUseCase` para `ESTABLISHMENT` já busca todos os usuários de todos os tenants vinculados ao `est_id`. Assim, `OFFICE → est_id parceiro` alcança a empresa, e `COMPANY → próprio est_id` alcança todos os escritórios que têm ela na carteira.

---

#### `CreateUserNotificationUseCase`

```javascript
// src/domain/use-cases/create-user-notification-use-case.js
import { DomainValidationError, ForbiddenError } from '../errors/index.js'

const OFFICE_TYPES = ['OFFICE', 'ACCOUNTANT']
const CLIENT_TYPES = ['COMPANY', 'INDIVIDUAL']

export class CreateUserNotificationUseCase {
  /**
   * @param {Object} deps
   * @param {import('../contracts/infrastructure/repositories/user-repository-contract.js').default} deps.userRepository
   * @param {import('../contracts/infrastructure/repositories/tax-entity-repository-contract.js').default} deps.taxEntityRepository
   * @param {import('../contracts/infrastructure/repositories/tenant-repository-contract.js').default} deps.tenantRepository
   * @param {import('../use-cases/send-notification-use-case.js').default} deps.sendNotificationUseCase
   * @param {Object} deps.logger
   */
  constructor({ userRepository, taxEntityRepository, tenantRepository, sendNotificationUseCase, logger }) {
    this._userRepository          = userRepository
    this._taxEntityRepository     = taxEntityRepository
    this._tenantRepository        = tenantRepository
    this._sendNotificationUseCase = sendNotificationUseCase
    this._logger                  = logger
  }

  /**
   * Envia uma mensagem de um usuário para outro usuário ou grupo, respeitando
   * os vínculos de carteira entre tenants.
   *
   * @param {Object} sessionUser
   * @param {Object} payload
   * @param {string} payload.notifScope        - 'USER' | 'ESTABLISHMENT' (ROOT também aceita 'TENANT' e 'BROADCAST')
   * @param {string} [payload.targetUserEmail] - Obrigatório para scope USER
   * @param {string} [payload.estId]           - Obrigatório para scope ESTABLISHMENT
   * @param {string} payload.notifTitle
   * @param {string} payload.notifMessage
   * @param {Object} [payload.notifMetadata]
   */
  async execute(sessionUser, payload) {
    const sender = await this._userRepository.findForSystem(sessionUser.email)

    // ROOT: delega diretamente sem checagem de vínculo
    if (sender.root) {
      return this._sendNotificationUseCase.execute({
        ...this.#buildBasePayload(payload, sender),
        tenantId: payload.targetTenantId ?? null, // ROOT pode especificar tenant arbitrário
      })
    }

    await this.#authorize(sender, payload)

    return this._sendNotificationUseCase.execute({
      ...this.#buildBasePayload(payload, sender),
      tenantId: sender.tenantId,
    })
  }

  // ─── Autorização ──────────────────────────────────────────────────────────

  async #authorize(sender, payload) {
    const senderType = sender.accountType

    if (payload.notifScope === 'USER') {
      if (payload.targetUserEmail === sender.email) {
        throw new DomainValidationError('Não é possível enviar notificação para si mesmo')
      }
      return OFFICE_TYPES.includes(senderType)
        ? this.#authorizeOfficeToUser(sender, payload.targetUserEmail)
        : this.#authorizeClientToUser(sender, payload.targetUserEmail)
    }

    if (payload.notifScope === 'ESTABLISHMENT') {
      return OFFICE_TYPES.includes(senderType)
        ? this.#authorizeOfficeToEstablishment(sender, payload.estId)
        : this.#authorizeClientToEstablishment(sender, payload.estId)
    }

    // TENANT e BROADCAST: apenas ROOT (já tratado acima)
    throw new ForbiddenError('Escopo não permitido para este tipo de conta')
  }

  /**
   * OFFICE/ACCOUNTANT → usuário de tenant parceiro
   * Verifica se o est_id do tenant do destinatário está na carteira do escritório.
   */
  async #authorizeOfficeToUser(sender, targetUserEmail) {
    const isLinked = await this._taxEntityRepository.isTargetUserInPortfolio(
      sender.tenantId,
      targetUserEmail
    )
    if (!isLinked) throw new ForbiddenError('Destinatário não é parceiro deste escritório')
  }

  /**
   * COMPANY/INDIVIDUAL → usuário de escritório parceiro
   * Verifica se o est_id do remetente está na carteira do tenant do destinatário.
   */
  async #authorizeClientToUser(sender, targetUserEmail) {
    const senderTenant = await this._tenantRepository.findById(sender.tenantId)
    const isLinked     = await this._taxEntityRepository.isPortfolioOwnerOfEst(
      targetUserEmail,
      senderTenant.estId
    )
    if (!isLinked) throw new ForbiddenError('Destinatário não é escritório parceiro deste tenant')
  }

  /**
   * OFFICE/ACCOUNTANT → todos vinculados a um est_id parceiro
   * Verifica se o est_id está na carteira do escritório.
   */
  async #authorizeOfficeToEstablishment(sender, estId) {
    const isLinked = await this._taxEntityRepository.existsByTenantAndEstablishment(
      sender.tenantId,
      estId
    )
    if (!isLinked) throw new ForbiddenError('Estabelecimento não pertence à carteira deste escritório')
  }

  /**
   * COMPANY/INDIVIDUAL → próprio est_id (alcança todos escritórios da carteira)
   * O remetente só pode usar o próprio est_id — qualquer outro é negado.
   */
  async #authorizeClientToEstablishment(sender, estId) {
    const senderTenant = await this._tenantRepository.findById(sender.tenantId)
    if (senderTenant.estId !== estId) {
      throw new ForbiddenError('Só é permitido enviar para o próprio estabelecimento')
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  #buildBasePayload(payload, sender) {
    return {
      notifScope:      payload.notifScope,
      targetUserEmail: payload.targetUserEmail ?? null,
      estId:           payload.estId           ?? null,
      notifType:       'TEAM_MESSAGE',
      notifTitle:      payload.notifTitle,
      notifMessage:    payload.notifMessage,
      createdBy:       sender.email,
      notifMetadata:   { ...(payload.notifMetadata ?? {}), senderEmail: sender.email },
    }
  }
}

export default CreateUserNotificationUseCase
```

---

#### Novos métodos no `TaxEntityRepository`

Dois métodos de autorização — adicionar no contrato e implementar com queries SQL nomeadas:

```javascript
// Adicionar em tax-entity-repository-contract.js

/**
 * Verifica se qualquer tenant ao qual targetUserEmail pertence
 * tem seu est_id na carteira de portfolioTenantId.
 * Uso: OFFICE → USER (o destinatário é parceiro do escritório?)
 */
async isTargetUserInPortfolio(portfolioTenantId, targetUserEmail) { throw new Error('Not implemented') }

/**
 * Verifica se qualquer tenant ao qual targetUserEmail pertence
 * tem estId em sua própria carteira (o destinatário é escritório do remetente?).
 * Uso: COMPANY/INDIVIDUAL → USER (o destinatário gere o est_id do remetente?)
 */
async isPortfolioOwnerOfEst(targetUserEmail, estId) { throw new Error('Not implemented') }
```

Queries SQL correspondentes:

```sql
-- select-target-user-in-portfolio.sql
-- $1 = portfolio_tenant_id (escritório remetente)
-- $2 = target_user_email   (destinatário)
-- "O destinatário pertence a algum tenant que está na carteira do escritório?"
SELECT EXISTS (
  SELECT 1
  FROM account.users_tenants ut
  JOIN partner.tenants t  ON t.tenant_id  = ut.tenant_id
  JOIN partner.tax_entities te ON te.est_id = t.est_id
                              AND te.tenant_id = $1
                              AND te.is_active = TRUE
  WHERE ut.email     = $2
    AND ut.is_active = TRUE
) AS exists;
```

```sql
-- select-portfolio-owner-of-est.sql
-- $1 = target_user_email (destinatário — deve ser escritório)
-- $2 = est_id            (estabelecimento do remetente cliente)
-- "O destinatário pertence a algum tenant que tem este est_id na carteira?"
SELECT EXISTS (
  SELECT 1
  FROM account.users_tenants ut
  JOIN partner.tax_entities te ON te.tenant_id = ut.tenant_id
                              AND te.est_id     = $2
                              AND te.is_active  = TRUE
  WHERE ut.email     = $1
    AND ut.is_active = TRUE
) AS exists;
```

---

#### Payload e Validation Schema do Endpoint

```
POST /v1/notifications/send
```

```javascript
// src/infrastructure/web/validation-schemas/send-notification-schema.js
import Joi from 'joi'

const ALLOWED_SCOPES = ['USER', 'ESTABLISHMENT']
const ROOT_SCOPES    = ['USER', 'ESTABLISHMENT', 'TENANT', 'BROADCAST']

export const sendNotificationSchema = Joi.object({
  notifScope:      Joi.string().valid(...ROOT_SCOPES).required(),
  targetUserEmail: Joi.string().email().when('notifScope', {
    is: 'USER', then: Joi.required(), otherwise: Joi.forbidden(),
  }),
  targetTenantId: Joi.string().uuid().when('notifScope', {
    is: 'TENANT', then: Joi.required(), otherwise: Joi.forbidden(),
  }),
  estId: Joi.string().uuid().when('notifScope', {
    is: 'ESTABLISHMENT', then: Joi.required(), otherwise: Joi.forbidden(),
  }),
  notifTitle:   Joi.string().min(1).max(255).required(),
  notifMessage: Joi.string().min(1).required(),
  notifMetadata: Joi.object().default({}),
}).options({ stripUnknown: true })
```

> O schema aceita todos os scopes (validação leve no schema), mas a lógica de autorização por `accountType` está no use case — não duplicar regras de negócio na camada HTTP.

---

#### Resumo de arquivos a criar/alterar para esta funcionalidade

| Arquivo | Ação |
|---|---|
| `tax-entity-repository-contract.js` | Adicionar `isTargetUserInPortfolio` e `isPortfolioOwnerOfEst` |
| `tax-entity-repository.js` | Implementar os dois métodos + 2 queries SQL nomeadas |
| `queries/notification/select-target-user-in-portfolio.sql` | Nova query |
| `queries/notification/select-portfolio-owner-of-est.sql` | Nova query |
| `create-user-notification-use-case.js` | Novo use case (substitui o esboço anterior) |
| `create-user-notification-controller.js` | Novo controller (padrão SRP) |
| `send-notification-schema.js` | Novo schema de validação com `notifScope` |
| `notifications-route.js` | `POST /send` registrada antes de `/:notificationId` |
| `container.js` | Registrar use case e controller |
| `openapi.yaml` | Documentar `POST /v1/notifications/send` |

---

## 14. RBAC — Módulos e Permissões

> ⚠️ **Workflow obrigatório antes de testar qualquer endpoint:**
>
> 1. Lucas: leia esta seção, entenda o padrão e **proponha** a estrutura de módulo/permissões no formato abaixo
> 2. Responsável: revisa, aprova ou ajusta, e cria as entradas no banco (roles, modules, permissions)
> 3. Lucas: recebe confirmação, implementa as chamadas ao `authorizerService` nos use cases e prossegue com os testes
>
> **Não implementar as chamadas de autorização antes da aprovação** — o `authorizerService.authorize()` lança `ForbiddenError` se a permissão não existir, o que bloquearia todos os testes prematuramente.

---

### 14.1 Como o Sistema de Permissões Funciona

O projeto usa o `AuthorizerService` para checar acesso por **módulo** e opcionalmente por **permissão específica**. O padrão já estabelecido nos use cases existentes:

```javascript
// Apenas módulo (acesso geral ao recurso)
await this._authorizerService.authorize(user, 'nfe')

// Módulo + permissão específica (ação granular)
await this._authorizerService.authorize(user, 'establishments', 'establishments:create')
```

Regras importantes do `AuthorizerService`:
- `root = true` → **sempre autorizado**, sem consultar o banco
- Sem `roleId` → `ForbiddenError` imediato
- A verificação é feita via JSONB no banco (busca ultra rápida)
- O `user` passado deve vir de `userRepository.findForSystem(email)`, que retorna os dados completos com `roleId`

---

### 14.2 Onde Adicionar Autorização nos Use Cases

Nem todo use case precisa de RBAC — operações auto-referenciadas (o usuário só acessa os próprios dados) são protegidas pelo JWT e pela validação de posse. Segue a análise:

| Use Case | Precisa de RBAC? | Justificativa |
|---|:---:|---|
| `FindNotificationsUseCase` | ✅ módulo | Garante que o módulo está habilitado para o role |
| `GetUnreadCountUseCase` | ✅ módulo | Idem |
| `MarkNotificationReadUseCase` | ❌ | JWT + `recipientExists` já protegem |
| `MarkAllNotificationsReadUseCase` | ❌ | Idem |
| `RemoveNotificationUseCase` | ❌ | Idem |
| `CreateUserNotificationUseCase` | ✅ módulo + permissão | Ação ativa que impacta outros usuários |
| `SendNotificationUseCase` (interno) | ❌ | Chamado por use cases que já têm auth |

O ponto de inserção em cada use case que precisa de RBAC — **adicionar após obter o `user` completo**:

```javascript
// Exemplo em FindNotificationsUseCase.execute():
async execute(sessionUser, queryParams = {}) {
  // 1. [AGUARDANDO APROVAÇÃO DO RBAC] — descomentar após criação das permissões
  // const user = await this._userRepository.findForSystem(sessionUser.email)
  // await this._authorizerService.authorize(user, '<MODULO_APROVADO>')

  // ... resto do método
}

// Exemplo em CreateUserNotificationUseCase.execute():
async execute(sessionUser, payload) {
  const sender = await this._userRepository.findForSystem(sessionUser.email)
  // [AGUARDANDO APROVAÇÃO DO RBAC] — descomentar após criação das permissões
  // await this._authorizerService.authorize(sender, '<MODULO_APROVADO>', '<MODULO_APROVADO>:send')

  if (sender.root) { /* ... */ }
  // ...
}
```

> **Nota sobre injeção de dependência**: os use cases que precisarem de RBAC precisarão receber `userRepository` e `authorizerService` no construtor, seguindo o padrão DIP do projeto. Verificar se já estão injetados antes de adicionar.

---

### 14.3 Sugestão a Submeter — Template para Lucas

Lucas, preencha o template abaixo com sua proposta e envie para aprovação **antes de qualquer implementação de RBAC**:

---

**Proposta de Módulo e Permissões — Sistema de Notificações**

```
Módulo proposto:
  nome: ???
  label (exibição): ???
  descrição: ???

Permissões propostas:
  1. ???:list    — descrição do que permite
  2. ???:send    — descrição do que permite
  (adicionar outras se julgar necessário)

Quais roles devem ter acesso ao módulo por padrão?
  - OFFICE:      permissões ???
  - ACCOUNTANT:  permissões ???
  - COMPANY:     permissões ???
  - INDIVIDUAL:  permissões ???

Dúvidas ou pontos de atenção:
  - ???
```

---

**Referência — padrão de nomes existentes no projeto para guiar a proposta:**

| Módulo existente | Permissões |
|---|---|
| `nfe` | `nfe:upload`, `nfe:list` |
| `establishments` | `establishments:create`, `establishments:update`, `establishments:sync` |
| `users` | `users:list`, `users:create` |
| `rbac` | `rbac:list`, `rbac:create`, `rbac:update` |

> Use o mesmo padrão `módulo:ação` em `snake_case`. Evite permissões muito genéricas (`notifications:manage`) — prefira granularidade por ação para facilitar auditorias futuras.

---

### 14.4 Atualizar a Ordem de Implementação

Quando a aprovação chegar, adicionar como passo **2b** na seção 12:

```
2b. [APÓS APROVAÇÃO] Implementar authorizerService nos use cases
    FindNotificationsUseCase e CreateUserNotificationUseCase
```
