---
name: stack-nextjs-tailwind-prisma
description: Convenciones del stack React 19 + Next.js 15 (App Router, Server Components y Server Actions) + Tailwind CSS + PostgreSQL con Prisma ORM, validación con Zod y autenticación segura. Define estructura, comandos, reglas de cliente/servidor y trampas conocidas. Usar siempre que se desarrolle, pruebe o despliegue código en proyectos con este stack. No usar para proyectos basados en stack-angular-express-postgres.
---

# Stack: Next.js + Tailwind CSS + Prisma + PostgreSQL

Esta skill define el **cómo técnico concreto** para aplicaciones modernas construidas sobre Next.js App Router; las skills de rol (`frontend-agent`, `backend-agent`, etc.) rigen el proceso. Si una convención de este stack difiere de una regla genérica, prevalece esta especificación. Cualquier excepción debe registrarse como un ADR en `GLOBAL_STATE.md` §6.

---

## 1. Versiones de Referencia (verificadas 2026-10)

| Pieza | Versión | Notas |
| :--- | :--- | :--- |
| **Node.js** | 22 / 24 LTS | Runtime de ejecución y scripts |
| **Next.js** | 15.x | App Router con React Server Components (RSC) y Server Actions nativas |
| **React** | 19.x | `useActionState`, `useOptimistic` y transiciones asíncronas |
| **Tailwind CSS** | 4.x / 3.4+ | Utility-first CSS con tokens semánticos y soporte para modo oscuro |
| **Prisma ORM** | 6.x | Cliente singleton tipado y migraciones SQL versionadas |
| **PostgreSQL** | 16+ | Base de datos relacional; IDs con `uuid` o `cuid` |
| **Zod** | 3.x / 4.x | Validación de esquemas en Server Actions, APIs y DTOs |
| **Testing** | Vitest + Playwright | Pruebas unitarias/integración y flujos E2E completos |

---

## 2. Estructura Canónica del Proyecto

```text
<proyecto>/
├── app/                          # App Router (RSC por defecto)
│   ├── (auth)/                   # Grupo de rutas de autenticación
│   ├── (dashboard)/              # Grupo de rutas privadas
│   ├── api/                      # Route Handlers para webhooks y consumo externo
│   ├── layout.tsx                # Layout raíz con providers mínimos
│   ├── page.tsx                  # Landing pública
│   └── globals.css               # Directivas de Tailwind y variables de diseño
├── components/
│   ├── ui/                       # Componentes base accesibles (Button, Input, Modal...)
│   └── forms/                    # Formularios interactivos ('use client')
├── lib/
│   ├── prisma.ts                 # Instancia Singleton de PrismaClient
│   ├── auth.ts                   # Configuración y utilidades de sesión
│   ├── utils.ts                  # Función canónica cn (clsx + twMerge)
│   └── schemas/                  # Contratos Zod y DTOs compartidos
├── prisma/
│   ├── schema.prisma             # Modelos de datos y relaciones
│   └── migrations/               # Historial de migraciones SQL versionadas
├── e2e/                          # Pruebas Playwright (ver skill e2e-testing)
├── docker-compose.yml            # PostgreSQL local
└── .env.example                  # Variables de entorno documentadas
```

---

## 3. Reglas de Oro del Stack

1. **Server Components por Defecto**: Todo componente es RSC salvo que requiera interactividad (hooks, eventos); en tal caso, se añade `'use client'` estrictamente en las hojas del árbol.
2. **Consultas a BD solo en Servidor**: Prohibido importar o instanciar Prisma en componentes de cliente (`'use client'`). Toda consulta o mutación corre en Server Components, Server Actions o Route Handlers.
3. **Server Actions Validadas con Zod**: Toda Server Action valida sus parámetros con un esquema Zod estricto y verifica la sesión del usuario antes de ejecutar mutaciones.
4. **Cliente Singleton de Prisma**: Usar la convención global (`lib/prisma.ts`) para evitar agotar el pool de conexiones en desarrollo.
5. **Migraciones Versionadas**: En desarrollo se usa exclusivamente `npx prisma migrate dev`; en producción y CI solo `npx prisma migrate deploy`. Prohibido `prisma db push` en producción.
6. **Tokens y Clases Semánticas**: Emplear siempre los tokens semánticos de Tailwind (`bg-background`, `text-primary`, `border-border`); prohibidos estilos arbitrarios o colores literales desalineados.
7. **Secretos Seguros**: Variables que contienen claves (`DATABASE_URL`, `AUTH_SECRET`, `STRIPE_SECRET_KEY`) **nunca** llevan el prefijo `NEXT_PUBLIC_`.

---

## 4. Comandos Canónicos

| Acción | Comando |
| :--- | :--- |
| **Base de datos local** | `docker compose up -d` |
| **Servidor de desarrollo** | `npm run dev` (o `pnpm dev`) |
| **Generar migración** | `npx prisma migrate dev --name <descripcion>` |
| **Aplicar migraciones** | `npx prisma migrate deploy` |
| **Explorador de datos** | `npx prisma studio` |
| **Comprobación de tipos** | `npm run typecheck` (`tsc --noEmit`) |
| **Tests unitarios** | `npm test` (Vitest) |
| **Build de producción** | `npm run build` |
| **Tests E2E** | `npx playwright test` |

---

## 5. Referencias por Capa (leer la correspondiente)

- **Next.js App Router & Server Actions**: [nextjs-app-router.md](references/nextjs-app-router.md)
- **PostgreSQL & Prisma ORM**: [prisma-postgres.md](references/prisma-postgres.md)
- **Tailwind CSS & Componentes UI**: [tailwind-design.md](references/tailwind-design.md)

---

## 6. Trampas Conocidas (*Gotchas*)

- **Llamadas a `headers()` o `cookies()` vuelven la ruta dinámica**: En Server Components, acceder a cabeceras desactiva el renderizado estático y fuerza evaluación en servidor para esa ruta.
- **Error "PrismaClient is unable to be run in the browser"**: Se produce por importar `prisma` directa o indirectamente dentro de un archivo con `'use client'`. Mueve la consulta a una Server Action en un archivo `'use server'`.
- **Caché en Server Actions**: Las mutaciones deben invalidar la caché de las vistas afectadas invocando `revalidatePath('/ruta')` o `revalidateTag('tag')`.
- **Variables de entorno en tiempo de build**: Next.js evalúa variables estáticas en build. Si una página SSG necesita `DATABASE_URL` en build, asegúrate de que esté configurada o usa `export const dynamic = 'force-dynamic'` para rutas dinámicas.

---

## 7. Checklist antes de `task.sh handoff`
- [ ] Directiva `'use client'` utilizada únicamente en componentes hoja que requieren interactividad.
- [ ] Instancia de Prisma singleton importada desde `lib/prisma.ts`.
- [ ] Parámetros de Server Actions validados sintáctica y semánticamente con Zod.
- [ ] Migraciones de Prisma generadas con `prisma migrate dev` y versionadas en Git.
- [ ] Variables sensibles sin prefijo `NEXT_PUBLIC_`.
- [ ] `npm run typecheck` y `npm run build` pasan con 0 errores.
- [ ] Escaneo de secretos limpio ejecutado con `./.agents/scripts/scan-secrets.sh --branch`.

## 8. Prohibido
- Importar Prisma o acceder a la base de datos desde componentes declarados con `'use client'`.
- Ejecutar `prisma db push` en entornos de producción o staging.
- Exponer credenciales secretas o cadenas de conexión en el bundle del cliente con `NEXT_PUBLIC_`.
- Omitir validación de autorización o de esquema Zod en Server Actions y Route Handlers.
