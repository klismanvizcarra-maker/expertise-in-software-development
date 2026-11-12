# Diagramas C4 (Mermaid), OpenAPI 3.x, ADRs y CHANGELOG

Guía de verificación documental complementaria a `docs-architecture-agent`.

## 1. Diagramas C4 y Flujos Seguros con Mermaid

Modela la arquitectura existente desde arriba hacia abajo según la complejidad real:
- **C4 Nivel 1 (Contexto) y Nivel 2 (Contenedores)** mediante `flowchart TB` con IDs ASCII simples y etiquetas entre comillas dobles cuando contengan paréntesis, barras o caracteres especiales:
  ```mermaid
  flowchart TB
    user["Usuario Web"] --> web["Frontend Web (SSR/SPA)"]
    web --> api["API Backend (REST / JSON)"]
    api --> db[("PostgreSQL")]
    api -.-> queue["Worker / Cola (Async Jobs)"]
  ```
- **Flujos críticos** (auth/OAuth, webhooks Stripe, subidas pre-firmadas) → `sequenceDiagram`.
- **Modelo de persistencia** → `erDiagram`; **ciclos de vida** → `stateDiagram-v2`.
- **Reglas anti-errores de render**: usa únicamente diagramas soportados (`flowchart`, `sequenceDiagram`, `erDiagram`, `stateDiagram-v2`, `classDiagram`, `xychart-beta`), evita etiquetas HTML (`<br/>`) dentro de nodos y no inventes servicios que no existan en el código.

## 2. Checklist OpenAPI 3.x (`docs/api/openapi.yaml`)

- [ ] Versión declarada (`openapi: 3.1.0` o `3.0.3`), `servers` con URL relativa o placeholder (`/api/v1`) y `components.securitySchemes` (`bearerAuth` / cookie) coincidente con el backend.
- [ ] Cada endpoint en `GLOBAL_STATE.md` §4 y en los routers reales tiene `summary`, `operationId` único, `parameters` / `requestBody` alineados al esquema Zod/Pydantic real y respuestas `2xx`, `400/422`, `401`, `403/404`, `409`.
- [ ] Todo esquema de error coincide con el envoltorio real del stack (`{ success: false, error: { code, message } }` en Express/Next.js según `api_response_template.ts`, o el `response_model`/error de FastAPI en `/openapi.json`).
- [ ] Cada operación relevante incluye un `example` concreto sin credenciales reales (solo valores sintéticos como `sk_test_example` o `user@example.com`).

## 3. Registros de Decisiones de Arquitectura (ADR) y CHANGELOG

- **Cuándo crear un ADR (`docs/adr/ADR-NNN-titulo.md` usando [adr_template.md](../../../templates/adr_template.md))**:
  - Excepción a una convención de la skill `stack-*` o `observability` / `devops-cloud-agent` / `i18n`.
  - Elección o cambio de base de datos, caché, sistema de colas, mecanismo de auth o presupuesto de bundle.
  - Adopción de un stack propio fuera de los preconfigurados.
  - Registra la fila en `GLOBAL_STATE.md` §6 **y** conserva todas las secciones de `adr_template.md` (Contexto, Opciones consideradas, Decisión, Consecuencias positivas/negativas y Tabla comparativa).
- **CHANGELOG (`CHANGELOG.md`) y SemVer**:
  - Agrupa los cambios por categoría (*Keep a Changelog* en el idioma del proyecto: `Añadido` / `Added`, `Cambiado` / `Changed`, `Obsoleto` / `Deprecated`, `Eliminado` / `Removed`, `Corregido` / `Fixed`, `Seguridad` / `Security`).
  - No cambies el historial pasado salvo errata evidente; todo enlace relativo dentro de docs/ debe resolver a archivos reales del repositorio.

