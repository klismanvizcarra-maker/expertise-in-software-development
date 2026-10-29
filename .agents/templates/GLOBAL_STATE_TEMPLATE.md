# Documento de Estado Global (Global State Document)

> **Única Fuente de Verdad (SSOT)**: Todos los agentes leen y sincronizan su estado a través del `Orchestrator` en este documento para garantizar consistencia arquitectónica, trazabilidad de tareas y evitar pérdida de contexto.

---

## 1. Metadatos del Proyecto

- **Proyecto**: `[NOMBRE_DEL_PROYECTO]`
- **Descripción**: `[Breve descripción del alcance del proyecto]`
- **Estado Actual**: `INITIALIZATION` <!-- INITIALIZATION | IN_PROGRESS | IN_REVIEW | PRODUCTION_READY -->
- **Fase Actual**: `FASE 1: Setup y Arquitectura Base`
- **Última Actualización**: `YYYY-MM-DD`
- **Iteraciones Críticas Acumuladas**: `0 / 3`

---

## 2. Stack Tecnológico y Arquitectura

- **Frontend**: `[Framework: ej. React 19 / Angular 19 / Next.js / Vue 3]`
- **Backend**: `[Runtime / Framework: ej. Node.js + Express / Fastify / Python FastAPI / Go]`
- **Persistencia**: `[Base de datos: ej. PostgreSQL / SQLite / MongoDB / Redis]`
- **Autenticación**: `[Estrategia: ej. JWT Bearer / OAuth2 / Session Cookies]`
- **Infraestructura & Despliegue**: `[Plataforma: ej. Docker / Vercel / Render / AWS]`

---

## 3. Matriz de Agentes y Responsabilidades

| Agente | Rol Principal | Skill Asociada |
| :--- | :--- | :--- |
| **Orchestrator** | Coordinación, backlog y gestión de SSOT | `orchestrator-agent` |
| **Product Manager** | Alcance de producto, User Stories (Gherkin) y flujos | `product-manager-agent` |
| **Backend & Data** | APIs, lógica de negocio y seguridad server | `backend-agent` |
| **Frontend & UI** | Componentes, vistas y experiencia web | `frontend-agent` |
| **Mobile & Native** | Apps móviles (React Native/Flutter/iOS/Android) | `mobile-agent` |
| **QA & Security** | Pruebas automatizadas, OWASP y veto | `qa-security-agent` |
| **Database** | Modelado, migraciones y optimización SQL | `database-architect-agent` |
| **DevOps** | Pipelines CI/CD, builds y despliegues | `devops-cloud-agent` |
| **UI/UX** | Tokens de diseño, accesibilidad y guías de estilo | `ui-ux-agent` |
| **Domain Logic** | Reglas puras de negocio y cálculos | `domain-logic-agent` |
| **AI Integrator** | Modelos LLM (Ollama/Cloud), RAG y embeddings | `ai-integrator-agent` |
| **Docs & Architecture** | Diagramas Mermaid, OpenAPI, ADRs y contratos | `docs-architecture-agent` |

---

## 4. Contratos de Integración Activos (APIs y DTOs)

### 4.1 Endpoint: `[MÉTODO /ruta/ejemplo]`
- **Descripción**: Resumen del propósito del endpoint.
- **Request Payload**:
```json
{
  "campo_ejemplo": "string",
  "cantidad": 10
}
```
- **Response Payload (200 OK)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid-123",
    "campo_ejemplo": "string",
    "cantidad": 10,
    "created_at": "YYYY-MM-DDTHH:mm:ssZ"
  }
}
```

---

## 5. Tablero de Tareas Activas

| ID Tarea | Descripción | Asignado a | Estado | Iteración QA | Criterios de Aceptación |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `TASK-001` | Inicialización de arquitectura y esquema base | Orchestrator | `TODO` | `0/3` | Repositorio estructurado y builds pasando |
| `TASK-002` | Implementación de autenticación y endpoints core | Backend Agent | `BACKLOG` | `0/3` | Login funcional con JWT y tests al 100% |

> **Estados Válidos**: `BACKLOG` | `TODO` | `IN_PROGRESS` | `IN_REVIEW_QA` | `BLOCKED` | `DONE`

---

## 6. Historial de Decisiones de Arquitectura (ADR)

| Fecha | Decisión | Justificación | Estado |
| :--- | :--- | :--- | :--- |
| `YYYY-MM-DD` | Elección del stack base | Requisitos de rendimiento y experiencia del equipo | `APROBADO` |

---

## 7. Registro Cronológico de Entregables e Hitos

| Fecha | Agente Emisor | Agente Receptor | Tarea | Resumen del Hito |
| :--- | :--- | :--- | :--- | :--- |
| `YYYY-MM-DD` | Orchestrator | Equipo | `TASK-001` | Creación de tablero y asignación inicial |
