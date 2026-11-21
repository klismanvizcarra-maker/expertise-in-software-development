# SKILL MAESTRO

<div align="center">

[![CI Audit](https://github.com/klismanvizcarra-maker/expertise-in-software-development/actions/workflows/audit.yml/badge.svg)](https://github.com/klismanvizcarra-maker/expertise-in-software-development/actions)
![Version](https://img.shields.io/badge/version-v2.0.0-blue.svg?style=flat-square)
![Skills](https://img.shields.io/badge/skills-56%20expertos-success.svg?style=flat-square)
![Architecture](https://img.shields.io/badge/governance-multi--agent-purple.svg?style=flat-square)
![Protocol](https://img.shields.io/badge/protocol-MCP%20Native-yellow.svg?style=flat-square)
![AI Compatibility](https://img.shields.io/badge/AI-Claude%20Code%20%7C%20Antigravity-orange.svg?style=flat-square)
![Creator](https://img.shields.io/badge/creator-Klisman%20Vizcarra-cyan.svg?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)

</div>

```c
/**
 * ╔══════════════════════════════════════════════════════════════════════════════╗
 * ║   ███████╗██╗  ██╗██╗██╗     ██╗     ███╗   ███╗ █████╗ ███████╗███████╗     ║
 * ║   ██╔════╝██║ ██╔╝██║██║     ██║     ████╗ ████║██╔══██╗██╔════╝██╔════╝     ║
 * ║   ███████╗█████╔╝ ██║██║     ██║     ██╔████╔██║███████║█████╗  ███████╗     ║
 * ║   ╚════██║██╔═██╗ ██║██║     ██║     ██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║     ║
 * ║   ███████║██║  ██╗██║███████╗███████╗██║ ╚═╝ ██║██║  ██║███████╗███████║     ║
 * ║   ╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝     ║
 * ╠══════════════════════════════════════════════════════════════════════════════╣
 * ║  SYSTEM   : SKILL MAESTRO — Enterprise Multi-Agent Operating System         ║
 * ║  CREATOR  : Klisman Vizcarra                                                ║
 * ║  VERSION  : v2.0.0 Enterprise Edition                                       ║
 * ║  TARGETS  : Claude Code & Google Antigravity IDE                            ║
 * ╚══════════════════════════════════════════════════════════════════════════════╝
 */
```

> **Sistema operativo multi-agente determinista para Claude Code y Antigravity**. Convierte a los asistentes de IA en un equipo de ingeniería coordinado: 17 roles especializados, 56 skills, servidor MCP nativo, Live Dashboard interactivo, orquestador de enjambres concurrentes (`task.sh swarm`), ciclo de vida estricto, veto de QA independiente y memoria persistente que recuerda errores pasados.

---

## 🚀 Cómo Cargar en tu Proyecto (Quickstart)

> [!TIP]
> Puedes usar **`npx skill-maestro`** directamente (sin clonar el repositorio) o usar el instalador de `bash`. Compatible con macOS, Linux y Windows (WSL 2).

### ⚡ Opción 1: Ejecución Directa con NPX (Recomendada)
```bash
# Inicializar en un proyecto nuevo con stack preconfigurado y CI:
npx skill-maestro init "Mi Proyecto" ./mi-nuevo-proyecto --stack nextjs --ci

# Adoptar un repositorio existente (Brownfield):
npx skill-maestro adopt ./mi-repositorio-existente

# Iniciar Live Dashboard Kanban interactivo en tiempo real:
npx skill-maestro serve --port 4200

# Arrancar el servidor MCP nativo (Model Context Protocol):
npx skill-maestro mcp
```

### 📦 Opción 2: Clonando el Repositorio
```bash
# 1. Clona el repositorio de la librería
git clone https://github.com/klismanvizcarra-maker/expertise-in-software-development.git skill-maestro

# 2. Inicializa tu proyecto con stack preconfigurado y CI automatizado
#    Stacks disponibles: nextjs, angular, fastapi, nuxt, react-vite, nestjs
./skill-maestro/.agents/scripts/init-project.sh "Mi Proyecto" ./mi-nuevo-proyecto --stack nextjs --ci

# 3. Entra a tu proyecto e instala los hooks de protección de gobernanza
cd ./mi-nuevo-proyecto && ./.agents/scripts/install-hooks.sh

# 4. Abre tu asistente de IA (Claude Code o Antigravity IDE) y ejecuta:
/iniciar-proyecto
```

### 2. En un Proyecto Existente (Brownfield)
```bash
# 1. Clona la librería (si aún no la tienes)
git clone https://github.com/klismanvizcarra-maker/expertise-in-software-development.git skill-maestro

# 2. Adopta tu repositorio existente (conserva tu código, dependencias y configuración intactas)
./skill-maestro/.agents/scripts/init-project.sh --adopt ./tu-proyecto-existente

# 3. Entra e instala los hooks
cd ./tu-proyecto-existente && ./.agents/scripts/install-hooks.sh

# 4. Abre tu asistente de IA y ejecuta:
/adoptar-proyecto
```

### 3. Actualizar la Librería en un Proyecto Activo
```bash
# Sincroniza las 56 skills, scripts y plantillas a la última versión
./skill-maestro/.agents/scripts/init-project.sh --update ./tu-proyecto
```

---

```typescript
import type { GovernanceFramework, AutonomousAgentSuite } from "@skill-maestro/core";

export const FrameworkConfig: GovernanceFramework = {
  name: "SKILL MAESTRO",
  version: "1.5.0",
  creator: "Klisman Vizcarra",
  architecture: "Deterministic Multi-Agent Governance & Continuous Learning",
  
  // Catálogo completo de capacidades
  roster: {
    totalSkills: 56,
    specializedRoles: 17,  // Orchestrator, Backend, Frontend, QA, Database, DevSecOps...
    workflowSkills: 19,    // /iniciar-proyecto, /crear-plan, /nueva-tarea, /qa-review...
    stackSpecialists: 8,   // Angular+Express, Next.js, FastAPI, Nuxt, Vite, NestJS...
    technicalSkills: 12,   // FinOps, Payments, SEO, Resilience, A11y, Security...
  },

  // Leyes inviolables del sistema multi-agente
  rules: {
    zeroCodeWithoutTask: true,         // Bloqueo estricto de edición sin tarea activa
    independentQaVeto: true,           // Poder de veto independiente (cero auto-aprobación)
    antiDeadlockLimit: 3,              // Máximo 3 rechazos -> escalamiento a humano
    mandatoryLearning: true,           // Lecciones aprendidas obligatorias ante defectos
    activeBrainLinting: true,          // Auditoría estricta de antipatrones en el código
  }
};
```

---

## ⚡ Flujo de Vida de una Tarea (State Machine)

```text
  [ USER / PRODUCT REQ ]
             │
             ▼
     orchestrator-agent  ──(task.sh add)──► [ TODO ]
             │                                   │
             ▼                                   ▼
      specialist-agent   ──(task.sh start)─► [ IN_PROGRESS ]
      (+ stack & tech)                           │
             │                                   │
             ▼                                   ▼
         /handoff        ──(task.sh handoff)► [ IN_REVIEW_QA ]
             │                                   │
             ▼                                   ▼
     qa-security-agent   ──[ Verificación Independiente en Limpio ]
             │
             ├──► RECHAZO (n/3) ──(task.sh reject)──► [ IN_PROGRESS ]
             │                                              │
             │                                       (al 3.º rechazo)
             │                                              ▼
             │                                         [ BLOCKED ] ──► ESCALAMIENTO AL HUMANO
             │
             └──► APROBADO ──────(task.sh close)───► [ DONE ]
                                                        │
                                                        ▼
                                              git merge --no-ff main
```

---

## 🧩 Anatomía del Ecosistema

```json
{
  "governance": {
    "AGENTS.md": "Reglas de oro, matriz de propiedad de código y protocolos de veto",
    "GLOBAL_STATE.md": "Fuente única de verdad: fases, tablero Kanban y contratos activos",
    "BRAIN.md": "Memoria persistente: lecciones (LL-XXX), deuda técnica (TD-XXX) y preferencias"
  },
  "cli": {
    "task.sh": "Comandos deterministas: add, start, hold, approve, handoff, reject, close, doctor, dashboard...",
    "pre-commit": "Escaneo automático de secretos y validación estructural de estado antes de cada commit"
  },
  "skills": {
    "roles": 17,
    "workflows": 19,
    "stacks": 8,
    "technical": 12
  }
}
```

### Roles Especializados (17 Agentes)
| Especialista | Responsabilidad Primaria | Límites y Zonas Prohibidas |
| :--- | :--- | :--- |
| `orchestrator-agent` | Coordinación global, tablero Kanban, dependencias | Lógica directa de código de producción |
| `product-manager-agent` | Especificaciones PRD, user stories Gherkin | Código productivo en `src/`, `server/` |
| `research-agent` | Análisis competitivo y benchmarks técnicos | Tareas `TASK-XXX`, código o PRDs |
| `backend-agent` | Controladores, servicios, DTOs, APIs REST/GraphQL | Componentes visuales UI o estilos CSS |
| `frontend-agent` | Vistas SPA/SSR, componentes reactivos, estado | Modelos de BD o queries SQL de servidor |
| `mobile-agent` | React Native, Expo, Flutter, apps nativas | Endpoints de backend o migraciones de BD |
| `database-architect-agent`| Modelado de datos, migraciones reversibles, índices | Endpoints de transporte HTTP |
| `qa-security-agent` | Verificación de criterios, auditorías OWASP, veto | Código productivo sin revisión previa |
| `user-testing-agent` | UAT exploratorio y validación en navegador real | Modificación directa de código fuente |
| `devops-cloud-agent` | Dockerfile, CI/CD, infraestructura, despliegue | Reglas de negocio puras |
| `devsecops-agent` | SAST, SCA, escaneo de CVEs, firmas Cosign | Lógica funcional de la aplicación |
| `domain-logic-agent` | DDD, cálculos matemáticos puros, estados críticos | Infraestructura o detalles HTTP |
| `ai-integrator-agent` | Integración de LLMs, embeddings, RAG, tool calling | Esquemas de base de datos no vectoriales |
| `data-engineer-agent` | Pipelines ETL/ELT, dbt, warehouses analíticos | Endpoints transaccionales de servidor |
| `ui-ux-agent` | Tokens de diseño, tipografía, paletas, accesibilidad visual | Controladores de backend |
| `compliance-legal-agent` | Licencias Open Source, privacidad GDPR/HIPAA | Código funcional sin consulta previa |
| `docs-architecture-agent`| Diagramas Mermaid, OpenAPI, ADRs, documentación | Lógica de negocio en código productivo |

---

## 🛠️ CLI de Control de Tareas (`task.sh`)

```bash
# Tablero y Métricas
./.agents/scripts/task.sh list                     # Ver estado del tablero Kanban
./.agents/scripts/task.sh metrics                  # Reporte de progreso y salud de QA
./.agents/scripts/task.sh doctor                   # Diagnóstico integral en 5 fases (exit 0/1)
./.agents/scripts/task.sh dashboard                # Genera dashboard interactivo HTML autónomo

# Ciclo de Vida
./.agents/scripts/task.sh add "<desc>" "<agente>" "<criterios>"  # Crear tarea (TODO)
./.agents/scripts/task.sh start TASK-XXX           # Iniciar tarea y crear rama git
./.agents/scripts/task.sh handoff TASK-XXX         # Entregar a revisión independiente de QA
./.agents/scripts/task.sh reject TASK-XXX "<motivo>" # Rechazar entrega (+1 iteración hasta 3/3)
./.agents/scripts/task.sh close TASK-XXX           # Aprobar y cerrar (DONE) con lección requerida

# Cerebro y Memoria Persistente
./.agents/scripts/task.sh brain for TASK-XXX       # Consultar lecciones relevantes para la tarea
./.agents/scripts/task.sh brain hotspots           # Mapa de rutas de alto riesgo por lecciones
./.agents/scripts/task.sh brain lint               # Audita activamente antipatrones en el código
./.agents/scripts/task.sh prefer "<cat>" "<regla>" # Registrar preferencia vinculante para agentes
```

---

## 🧪 Batería de Pruebas y Validación Continua

El ecosistema se somete a una suite rigurosa de 416 pruebas deterministas:

```bash
# 1. Validación de scripts, hooks y cerebro persistente
LC_ALL=C bash tests/test-scripts.sh

# 2. Simulación del ciclo completo de vida y reglas de veto
bash tests/test-flow.sh

# 3. Integridad y presupuesto de tokens de las 56 skills
bash tests/test-skills.sh
python3 tests/triggers/lint_descriptions.py

# 4. Verificación de líneas base deterministas para evals
python3 tests/evals/run_evals.py --verify-baselines
```

---

## 👨‍💻 Autoría y Créditos

- **Creador y Arquitecto**: **Klisman Vizcarra**
- **Repositorio Oficial**: [expertise-in-software-development](https://github.com/klismanvizcarra-maker/expertise-in-software-development)
- **Licencia**: MIT License — Diseñado para ingeniería de software enterprise asistida por IA.
