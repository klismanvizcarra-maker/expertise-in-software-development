# Crear un Proyecto Nuevo (Scaffold Verificado)

Configuración probada de punta a punta (2026-10): `ng build`, `ng test`, `tsc`, `drizzle-kit generate/migrate` sobre PostgreSQL 18 y tests de API con supertest.

## 1. Raíz

```bash
mkdir mi-app && cd mi-app && git init
./ruta/a/SKILL MAESTRO/.agents/scripts/init-project.sh "Mi App" .
```

`package.json`:
```json
{
  "name": "mi-app",
  "private": true,
  "type": "module",
  "workspaces": ["apps/*", "packages/*"],
  "engines": { "node": ">=24" },
  "scripts": {
    "dev": "npm run dev -w @app/api & npm start -w @app/web",
    "build": "npm run build --workspaces --if-present",
    "test": "npm test --workspaces --if-present"
  }
}
```

`docker-compose.yml`:
```yaml
services:
  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app_dev_password   # solo local
      POSTGRES_DB: app
    ports: ["5432:5432"]
    volumes: ["pgdata:/var/lib/postgresql"]  # PG 18: montar el directorio padre
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "app"]
      interval: 5s
volumes:
  pgdata:
```

`.env.example` (copiar a `.env`):
```bash
DATABASE_URL=postgres://app:app_dev_password@localhost:5432/app
PORT=3000
CORS_ORIGIN=http://localhost:4200
JWT_ACCESS_SECRET=cambia-esto-por-32-bytes-aleatorios
JWT_ACCESS_TTL=15m
REFRESH_TTL_DAYS=14
COOKIE_SECURE=false
```

## 2. `packages/shared`

`package.json`:
```json
{
  "name": "@app/shared",
  "private": true,
  "type": "module",
  "exports": { ".": "./src/index.ts" },
  "dependencies": { "zod": "^4" }
}
```
`src/index.ts` reexporta cada esquema con extensión: `export * from './auth.schema.ts';`

## 3. `apps/web` (Angular)

```bash
npx @angular/cli@22 new web --directory apps/web --skip-install --skip-git --style=css --ssr=false
```
Después:
- En `apps/web/package.json`: `"name": "@app/web"` y la dependencia `"@app/shared": "*"`.
- En `apps/web/tsconfig.json` → `compilerOptions`: `"allowImportingTsExtensions": true, "noEmit": true` (necesario para consumir `@app/shared`).
- `apps/web/proxy.conf.json` con `{ "/api": { "target": "http://localhost:3000", "secure": false } }` y en `angular.json` → `serve.options.proxyConfig: "proxy.conf.json"`.
- Copia `tokens_template.css` y `components_template.css` de `.agents/templates/` a `apps/web/src/styles/` e impórtalos desde `src/styles.css`.

## 4. `apps/api` (Express + Drizzle)

```bash
mkdir -p apps/api/src apps/api/test
npm i -w @app/api express@5 drizzle-orm pg zod helmet cors cookie-parser express-rate-limit pino pino-http argon2 jose
npm i -D -w @app/api drizzle-kit typescript@~6.0 vitest supertest @types/express @types/node@24 @types/pg @types/supertest @types/cors @types/cookie-parser
```
(Antes, crea `apps/api/package.json` con `"name": "@app/api"`, `"type": "module"` y la dependencia `"@app/shared": "*"`.)

Scripts de `apps/api/package.json`:
```json
{
  "dev": "node --watch --env-file-if-exists=../../.env src/server.ts",
  "start": "node src/server.ts",
  "typecheck": "tsc --noEmit",
  "test": "vitest run",
  "db:generate": "drizzle-kit generate",
  "db:migrate": "drizzle-kit migrate"
}
```

`apps/api/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2024",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "noEmit": true,
    "allowImportingTsExtensions": true,
    "erasableSyntaxOnly": true,
    "verbatimModuleSyntax": true,
    "skipLibCheck": true,
    "types": ["node"]
  },
  "include": ["src", "test", "drizzle.config.ts"]
}
```

`apps/api/drizzle.config.ts`:
```ts
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/db/schema/index.ts',
  out: './drizzle',
  casing: 'snake_case',
  dbCredentials: { url: process.env.DATABASE_URL! },
});
```
Los comandos `db:*` necesitan `DATABASE_URL` en el entorno (`node --env-file=../../.env` o exportarla).

## 5. Verificación del Scaffold
```bash
npm install
docker compose up -d db
npm run db:generate -w @app/api && npm run db:migrate -w @app/api
npm run typecheck -w @app/api && npm test && npm run build
```
Después ejecuta `/iniciar-proyecto` para registrar el stack en `GLOBAL_STATE.md`.
