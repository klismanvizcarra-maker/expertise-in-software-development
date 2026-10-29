---
name: stack-angular-express-postgres
description: Convenciones del stack web Angular 22 + Node 24 con Express 5 + PostgreSQL 18 con Drizzle ORM, en monorepo npm (apps/web, apps/api, packages/shared con contratos Zod), autenticación JWT propia y sistema de tokens CSS propio. Define estructura, comandos, librerías aprobadas y trampas conocidas. Usar siempre que se cree, modifique, pruebe o despliegue código en un proyecto con este stack, junto con la skill del rol (backend-agent, frontend-agent, database-architect-agent...), y al crear un proyecto nuevo con este stack.
---

# Stack: Angular + Express + PostgreSQL

Esta skill fija el **cómo** concreto; la skill del rol fija el proceso. Si algo de aquí contradice una skill de rol, manda esta (es más específica). Toda desviación se registra como ADR en `GLOBAL_STATE.md` §6.

## Versiones de Referencia (verificadas 2026-10)

| Pieza | Versión | Notas |
| :--- | :--- | :--- |
| Node.js | 24 LTS | Ejecuta TypeScript directamente (*type stripping*) |
| Angular | 22 | Standalone, zoneless y `OnPush` por defecto; tests con Vitest |
| TypeScript | ~6.0 | La que fija Angular; `strict` activo por defecto |
| Express | 5 | Errores de handlers `async` llegan solos al middleware de errores |
| PostgreSQL | 18 | `uuidv7()` nativo |
| Drizzle ORM / Kit | 0.45 / 0.31 | Migraciones SQL generadas, **sin `down`** |
| Zod | 4 | Contratos compartidos web ↔ api |
| Vitest / Playwright | 5 / 1.6x | Unitarias e integración / E2E |

Antes de fijar versiones en un proyecto nuevo, comprueba las actuales con `npm view <paquete> version`.

## Estructura del Monorepo

```text
<proyecto>/
├── package.json          # npm workspaces: apps/*, packages/*
├── docker-compose.yml    # PostgreSQL 18 local
├── .env / .env.example   # DATABASE_URL, JWT_*, CORS_ORIGIN...
├── apps/
│   ├── web/              # Angular 22  → frontend-agent, ui-ux-agent
│   └── api/              # Express 5   → backend-agent, database-architect-agent
├── packages/
│   └── shared/           # Esquemas Zod + tipos inferidos (contratos DTO) y src/domain/ (reglas puras)
└── e2e/                  # Playwright  → qa-security-agent
```

## Reglas de Oro del Stack

1. **El contrato es código**: cada DTO vive como esquema Zod en `packages/shared/src/<modulo>.schema.ts` y exporta su tipo (`z.infer`). La API valida con él y Angular tipa con él. En `GLOBAL_STATE.md` §4 se enlaza el archivo en vez de copiar JSON.
2. **Imports con extensión `.ts`** en `apps/api` y `packages/shared` (`import { db } from './db/client.ts'`): Node 24 ejecuta el TypeScript sin compilar.
3. **Solo sintaxis "borrable"** en la API (`erasableSyntaxOnly`): nada de `enum`, `namespace` ni *parameter properties*; usa uniones de literales u objetos `as const`.
4. **Migraciones solo con `drizzle-kit generate` + `migrate`**; `drizzle-kit push` únicamente contra una base local desechable.
5. **Dinero en enteros** (céntimos, `integer`/`bigint`), fechas `timestamptz`, IDs `uuid` con `uuidv7()`.
6. **El dominio es compartido**: las reglas puras de `domain-logic-agent` viven en `packages/shared/src/domain/` (no en `src/domain/` de una app), para que la API y Angular importen la misma implementación desde `@app/shared`. Sin dependencias de Node, Angular ni Drizzle.
7. **Tokens CSS del sistema** en `apps/web/src/styles/` (de `tokens_template.css` y `components_template.css`); los componentes solo usan `var(--...)`.

## Comandos (desde la raíz)

| Acción | Comando |
| :--- | :--- |
| Base de datos local | `docker compose up -d db` |
| API en desarrollo | `npm run dev -w @app/api` |
| Web en desarrollo | `npm start -w @app/web` (proxy `/api` → `localhost:3000`) |
| Generar migración | `npm run db:generate -w @app/api` → revisar el SQL en `apps/api/drizzle/` |
| Aplicar migraciones | `npm run db:migrate -w @app/api` |
| Tests | `npm test --workspaces --if-present` |
| Tipos API | `npm run typecheck -w @app/api` |
| Build | `npm run build --workspaces --if-present` |
| E2E | `npx playwright test` (ver skill `e2e-testing`) |

## Referencias por Capa (leer la que toque)

- **Crear un proyecto nuevo** (archivos de configuración verificados): [scaffold.md](references/scaffold.md)
- **Angular** (componentes, señales, formularios, datos, rutas, tests): [angular.md](references/angular.md)
- **Express** (estructura, middlewares, errores, validación, tests): [api-express.md](references/api-express.md)
- **PostgreSQL + Drizzle** (esquema, migraciones, transacciones, consultas): [database-drizzle.md](references/database-drizzle.md)
- **Autenticación JWT** (tokens, refresh con rotación, interceptor, guards): [auth-jwt.md](references/auth-jwt.md)

## Trampas Conocidas
- **Volumen de PostgreSQL 18 en Docker**: se monta en `/var/lib/postgresql` (no en `/var/lib/postgresql/data` como en versiones anteriores); con la ruta antigua los datos no persisten.
- **`ChangeDetectionStrategy.Default` está obsoleto** en Angular 22 (ahora `Eager`), y `OnPush` ya es el valor por defecto: no lo declares ni lo desactives salvo razón documentada.
- **`req.query` es de solo lectura en Express 5**: parsea a una variable nueva (`const q = ListQuery.parse(req.query)`), no lo reasignes.
- **Rutas comodín en Express 5** usan nombre: `/*splat` en lugar de `*`; los parámetros opcionales se escriben `{/:id}`.
- **Drizzle no genera migraciones `down`**: la reversión es una migración correctiva hacia delante (ver `database-drizzle.md`).
