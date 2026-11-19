#!/usr/bin/env bash
# Fixture: Proyecto brownfield existente en Node/Express listo para ser adoptado por el sistema.
set -euo pipefail

mkdir -p src test
cat > package.json <<'EOF'
{
  "name": "legacy-express-api",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "express": "^4.19.2"
  }
}
EOF

cat > src/index.js <<'EOF'
import express from 'express';
export const app = express();
app.get('/health', (req, res) => res.json({ status: 'ok' }));
EOF

cat > test/health.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
test('health test', () => assert.equal(1, 1));
EOF

# Restaurar placeholders en GLOBAL_STATE.md para que la adopción los sustituya
cat > GLOBAL_STATE.md <<'EOF'
# Documento de Estado Global (Global State Document)

> **Única Fuente de Verdad (SSOT)**: Todos los agentes leen y sincronizan su estado a través del `Orchestrator`.

---

## 1. Metadatos del Proyecto

- **Proyecto**: `[Nombre del Proyecto]`
- **Descripción**: `[Breve descripción del producto y propósito arquitectónico]`
- **Estado Actual**: `IN_PROGRESS`
- **Fase Actual**: `FASE 1: Adopción y Estabilización`
- **Última Actualización**: `2026-11-19`
- **Iteraciones Críticas Acumuladas**: `0 / 3`

---

## 2. Stack Tecnológico y Arquitectura

- **Core**: `[Elegir: Next.js 15 / Angular 19 / React + Vite / FastAPI / Node]`
- **Base de Datos**: `[Elegir: PostgreSQL / SQLite / MySQL / MongoDB]`
- **Estilos & UI**: `[Elegir: Tailwind CSS / Shadcn UI / CSS Modules]`
- **Pruebas**: `[Elegir: Vitest + Playwright / Jest + Cypress / Pytest]`
- **Infraestructura**: `[Elegir: Docker / Vercel / AWS / GCP]`

---

## 3. Matriz de Agentes y Responsabilidades

| Agente | Rol Principal | Skill Asociada |
| :--- | :--- | :--- |
| **Orchestrator** | Coordinación y backlog | `orchestrator-agent` |
| **Backend & Data** | Servidor y APIs | `backend-agent` |
| **QA & Security** | Pruebas y veto | `qa-security-agent` |

---

## 4. Contratos de Integración Activos (APIs y DTOs)

*Por definir tras adopción.*

---

## 5. Tablero de Tareas Activas

| ID Tarea | Descripción | Asignado a | Estado | Iteración QA | Criterios de Aceptación |
| :--- | :--- | :--- | :--- | :---: | :--- |

---

## 6. Historial de Decisiones de Arquitectura (ADR)

| Fecha | Decisión | Justificación | Estado |
| :--- | :--- | :--- | :--- |

---

## 7. Registro Cronológico de Entregables e Hitos

| Fecha | Agente Emisor | Agente Receptor | Tarea | Resumen del Hito |
| :--- | :--- | :--- | :--- | :--- |
EOF

git add -A && git commit -qm "chore(TASK-000): setup inicial brownfield con placeholders" --no-verify
