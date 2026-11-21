# Global State Document

> **Single Source of Truth (SSOT)**: All agents read and synchronize their state through the `Orchestrator` in this document to ensure architectural consistency, task traceability, and eliminate context loss.

---

## 1. Project Metadata

- **Project**: `[NOMBRE_DEL_PROYECTO]`
- **Description**: `[Brief description of project scope]`
- **Current Status**: `INITIALIZATION` <!-- INITIALIZATION | IN_PROGRESS | IN_REVIEW | PRODUCTION_READY -->
- **Current Phase**: `PHASE 1: Setup & Base Architecture`
- **Last Updated**: `YYYY-MM-DD`
- **Accumulated Critical Iterations**: `0 / 3`

---

## 2. Tech Stack & Architecture

- **Frontend**: `[Framework: e.g., React 19 / Angular 19 / Next.js / Vue 3]`
- **Backend**: `[Runtime / Framework: e.g., Node.js + Express / Fastify / Python FastAPI / Go]`
- **Persistence**: `[Database: e.g., PostgreSQL / SQLite / MongoDB / Redis]`
- **Authentication**: `[Strategy: e.g., JWT Bearer / OAuth2 / Session Cookies]`
- **Infrastructure & Deployment**: `[Platform: e.g., Docker / Vercel / Render / AWS]`

---

## 3. Agent Matrix & Responsibilities

| Agent | Core Role | Associated Skill |
| :--- | :--- | :--- |
| **Orchestrator** | Coordination, backlog and SSOT management | `orchestrator-agent` |
| **Research** | Market & competitor research, proposal for the project | `research-agent` |
| **Product Manager** | Product scope, User Stories (Gherkin) and flows | `product-manager-agent` |
| **Backend & Data** | APIs, business logic and server security | `backend-agent` |
| **Frontend & UI** | Components, views and web experience | `frontend-agent` |
| **Mobile & Native** | Mobile apps (React Native/Flutter/iOS/Android) | `mobile-agent` |
| **QA & Security** | Automated testing, OWASP audit and veto power | `qa-security-agent` |
| **Database** | Data modeling, migrations and SQL optimization | `database-architect-agent` |
| **DevOps** | CI/CD pipelines, builds and deployments | `devops-cloud-agent` |
| **UI/UX** | Design tokens, accessibility and style guides | `ui-ux-agent` |
| **Domain Logic** | Pure business rules and domain calculations | `domain-logic-agent` |
| **AI Integrator** | LLM models (Ollama/Cloud), RAG and embeddings | `ai-integrator-agent` |
| **Docs & Architecture** | Mermaid diagrams, OpenAPI, ADRs and contracts | `docs-architecture-agent` |

---

## 4. Active Integration Contracts (APIs & DTOs)

### 4.1 Endpoint: `[METHOD /route/example]`
- **Description**: Summary of the endpoint purpose.
- **Request Payload**:
```json
{
  "example_field": "string",
  "quantity": 10
}
```
- **Response Payload (200 OK)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid-123",
    "example_field": "string",
    "quantity": 10,
    "created_at": "YYYY-MM-DDTHH:mm:ssZ"
  }
}
```

---

## 5. Master Task Board

| Task ID | Description | Assigned Agent | Status | QA Iteration | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `TASK-001` | Architecture initialization and baseline schema | `orchestrator-agent` | `TODO` | `0/3` | Repository structured and builds passing |
| `TASK-002` | Authentication implementation and core endpoints | `backend-agent` | `BACKLOG` | `0/3` | Functional JWT login with 100% tests passing |

> **Valid States**: `BACKLOG` | `TODO` | `AWAITING_HUMAN_APPROVAL` | `IN_PROGRESS` | `IN_REVIEW_QA` | `BLOCKED` | `DONE`

---

## 6. Architecture Decision Records (ADR)

| Date | Decision | Rationale | Status |
| :--- | :--- | :--- | :--- |
| `YYYY-MM-DD` | Selection of core tech stack | Performance requirements and team experience | `APPROVED` |

---

## 7. Deliverables & Milestones Chronological Log

| Date | Sender Agent | Receiver Agent | Task | Milestone Summary |
| :--- | :--- | :--- | :--- | :--- |
| `YYYY-MM-DD` | `orchestrator-agent` | `backend-agent` | `TASK-001` | Task board initialization and assignment |
