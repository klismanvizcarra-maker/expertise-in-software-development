---
name: stack-vue-nuxt-postgres
description: Convenciones del stack Vue 3 + Nuxt 3 (SSR, Nitro engine y Composition API) + Pinia + Tailwind CSS + PostgreSQL con Drizzle ORM y validación con Zod. Define estructura canónica, comandos, manejo de hidratación y trampas conocidas. Usar siempre que se cree, modifique, pruebe o despliegue código en proyectos con este stack. No usar para proyectos basados en stack-angular-express-postgres, stack-nextjs-tailwind-prisma ni stack-fastapi-postgres.
---

# Stack: Vue 3 + Nuxt 3 + Pinia + Drizzle ORM + PostgreSQL

Esta skill define el **cómo técnico concreto** para aplicaciones web construidas con Nuxt 3 (Vue 3) y persistencia relacional con PostgreSQL; las skills de rol (`frontend-agent`, `backend-agent`, `database-architect-agent`, etc.) rigen el proceso. Si una convención de este stack difiere de una regla genérica, prevalece esta especificación. Cualquier excepción debe registrarse como un ADR en `GLOBAL_STATE.md` §6.

---

## 1. Versiones de Referencia (verificadas 2026-11-18)

| Pieza | Versión | Notas |
| :--- | :--- | :--- |
| **Node.js** | 22 / 24 LTS | Runtime de ejecución y build |
| **Nuxt** | 3.14.x / 3.x | Framework full-stack con motor Nitro y auto-imports |
| **Vue** | 3.5.x | Composition API con `<script setup lang="ts">` |
| **Pinia** | 2.2.x | Gestión de estado reactivo y tipado con soporte SSR |
| **Tailwind CSS** | 4.x / 3.4+ | Estilos de utilidad y diseño responsivo |
| **Drizzle ORM** | 0.36.x / 0.x | ORM TypeScript con inferencia estricta de esquemas SQL |
| **PostgreSQL** | 16+ | Base de datos relacional; IDs con UUID v4 |
| **Zod** | 3.x / 4.x | Validación estricta en queries y cuerpos de peticiones |
| **Testing** | Vitest + Playwright | Pruebas unitarias de composables/stores y flujos E2E |

---

## 2. Estructura Canónica del Proyecto

```text
<proyecto>/
├── app.vue                       # Entrada principal de la app Nuxt
├── nuxt.config.ts                # Configuración de módulos (Pinia, Tailwind), runtime config
├── drizzle.config.ts             # Configuración de Drizzle Kit y esquemas
├── pages/                        # Enrutamiento basado en archivos (file-based routing)
│   ├── index.vue                 # Página de inicio / landing
│   ├── (auth)/                   # Rutas de autenticación (login, registro)
│   └── dashboard/                # Vistas protegidas de usuario
├── layouts/                      # Layouts reutilizables (default.vue, auth.vue)
├── components/                   # Componentes Vue auto-importados
│   ├── ui/                       # Componentes base (Button.vue, Modal.vue, Input.vue)
│   └── forms/                    # Formularios con validación reactiva
├── composables/                  # Lógica reutilizable auto-importada (useAuth, useToast)
├── stores/                       # Stores de Pinia (useAuthStore, useCartStore)
├── server/                       # Backend impulsado por Nitro
│   ├── api/                      # Endpoints HTTP (defineEventHandler)
│   ├── middleware/               # Middlewares del servidor (auth, logger)
│   ├── utils/                    # Utilidades de servidor (db.ts singleton auto-importado)
│   └── db/                       # Esquemas y migraciones de Drizzle
│       ├── schema.ts             # Definición de tablas y relaciones
│       └── migrations/           # Archivos SQL generados por drizzle-kit
├── e2e/                          # Pruebas end-to-end con Playwright
├── docker-compose.yml            # PostgreSQL local
└── .env.example                  # Variables de entorno documentadas
```

---

## 3. Reglas de Oro del Stack

1. **Composition API con `<script setup>`**: Todo componente y vista se escribe obligatoriamente con Composition API y TypeScript (`<script setup lang="ts">`). Prohibido el uso de Options API en código nuevo.
2. **Consultas a BD estrictamente en Servidor**: Las tablas y el cliente `db` de Drizzle **nunca** se importan en archivos dentro de `pages/`, `components/` o `composables/`. Toda interacción con la base de datos corre en `server/api/` o `server/routes/`.
3. **Manejo Correcto de Asincronía en SSR**: Dentro de `<script setup>`, las peticiones a endpoints se realizan con `useFetch` o `useAsyncData`. Prohibido usar `$fetch` o `fetch` nativo sin envolver en la raíz del setup de un componente para prevenir peticiones dobles y *hydration mismatches*.
4. **Validación de Entradas con Zod y H3**: Todo endpoint en `server/api/` valida sus parámetros usando `getValidatedQuery` o `readValidatedBody` con esquemas Zod antes de ejecutar cualquier lógica de negocio.
5. **Aislamiento de Stores en SSR**: Los stores de Pinia se definen exclusivamente con Setup Syntax (`defineStore('id', () => ...)`). Nunca declarar variables reactivas (`ref`/`reactive`) globales fuera del closure de la función del store.
6. **Migraciones Versionadas con Drizzle**: Los cambios de esquema se generan con `npx drizzle-kit generate` y se aplican con `npx drizzle-kit migrate`. Prohibido `push` directo en entornos de producción.
7. **Variables Privadas Seguras**: Claves criptográficas, credenciales y `DATABASE_URL` residen en `runtimeConfig` privado en `nuxt.config.ts` o variables de entorno, nunca bajo `runtimeConfig.public`.

---

## 4. Comandos Canónicos

| Acción | Comando |
| :--- | :--- |
| **Base de datos local** | `docker compose up -d` |
| **Servidor de desarrollo** | `npm run dev` (o `pnpm dev`) |
| **Generar migración SQL** | `npx drizzle-kit generate` |
| **Aplicar migraciones** | `npx drizzle-kit migrate` |
| **Explorador de datos** | `npx drizzle-kit studio` |
| **Comprobación de tipos** | `npx nuxi typecheck` |
| **Tests unitarios** | `npm test` (Vitest) |
| **Build de producción** | `npm run build` |
| **Tests E2E** | `npx playwright test` |

---

## 5. Referencias por Capa (leer la correspondiente)

- **Nitro Server API & SSR**: [nuxt-nitro-api.md](references/nuxt-nitro-api.md)
- **Gestión de Estado con Pinia**: [pinia-state.md](references/pinia-state.md)
- **PostgreSQL & Drizzle ORM**: [drizzle-postgres.md](references/drizzle-postgres.md)

---

## 6. Trampas Conocidas (*Gotchas*)

- **Hydration Mismatch con `$fetch` en Setup**: Usar `const data = await $fetch('/api/...')` directamente en `<script setup>` causa que el servidor ejecute la petición y el cliente la vuelva a ejecutar al montar, provocando mismatch de HTML o parpadeos. Usa siempre `const { data } = await useFetch('/api/...')`.
- **Acceso a `window` / `localStorage` en Servidor**: El setup de Nuxt se ejecuta primero en Node.js donde `window` es `undefined`. Envuelve accesos a APIs del navegador dentro de `onMounted()` o en componentes `<ClientOnly>`.
- **Auto-imports de Nuxt en subdirectorios**: Los componentes en `components/` se auto-importan con prefijos según su carpeta (ej. `components/ui/Button.vue` se usa como `<UiButton />` o requiere configurar `pathPrefix: false` en `nuxt.config.ts`).
- **Secretos en runtimeConfig**: Las claves en `runtimeConfig.public` se exponen en el bundle JavaScript del cliente. Claves de API privadas y tokens de servicio deben definirse exclusivamente en la raíz de `runtimeConfig`.
