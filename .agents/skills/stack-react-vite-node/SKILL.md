---
name: stack-react-vite-node
description: Convenciones del stack SPA React 19 + Vite + Tailwind CSS + Node.js (Express o Hono) con PostgreSQL y TanStack Query. Define arquitectura cliente/servidor, proxying, manejo de estado asíncrono y trampas conocidas. Usar siempre que se cree, modifique, pruebe o despliegue código en proyectos con este stack. No usar para proyectos basados en stack-nextjs-tailwind-prisma, stack-angular-express-postgres, stack-fastapi-postgres ni stack-vue-nuxt-postgres.
---

# Stack: React 19 + Vite + Tailwind CSS + Node.js + PostgreSQL

Esta skill define el **cómo técnico concreto** para aplicaciones Single Page Application (SPA) desacopladas construidas con React 19 y empaquetadas con Vite, respaldadas por un backend en Node.js (Express o Hono) y base de datos PostgreSQL; las skills de rol (`frontend-agent`, `backend-agent`, etc.) rigen el proceso. Si una convención de este stack difiere de una regla genérica, prevalece esta especificación. Cualquier excepción debe registrarse como un ADR en `GLOBAL_STATE.md` §6.

---

## 1. Versiones de Referencia (verificadas 2026-11-18)

| Pieza | Versión | Notas |
| :--- | :--- | :--- |
| **Node.js** | 22 / 24 LTS | Runtime de servidor y herramientas de build |
| **React** | 19.x | Interfaz SPA reactiva, Suspense y nuevos hooks de formulario |
| **Vite** | 6.x / 5.x | Build tool ultrarrápido con Hot Module Replacement (HMR) |
| **Tailwind CSS** | 4.x / 3.4+ | Estilos atómicos semánticos y modo oscuro |
| **TanStack Query** | 5.x | Gestión de caché y sincronización de estado de servidor |
| **Backend API** | Express 5.x / Hono 4.x | Servidor REST modular con validación Zod |
| **ORM / Query Builder** | Drizzle ORM 0.36+ / Prisma 6+ | Persistencia relacional tipada sobre PostgreSQL 16+ |
| **Testing** | Vitest + React Testing Library + Playwright | Suites de componentes y pruebas de integración E2E |

---

## 2. Estructura Canónica del Proyecto

```text
<proyecto>/
├── client/                       # Frontend SPA (React + Vite)
│   ├── src/
│   │   ├── components/ui/        # Componentes atómicos accesibles
│   │   ├── features/             # Módulos por dominio (auth, products, users)
│   │   │   ├── api/              # Hooks y queries TanStack
│   │   │   └── components/       # Vistas y formularios del módulo
│   │   ├── layouts/              # Layouts de aplicación (AppLayout, AuthLayout)
│   │   ├── lib/                  # Cliente HTTP, utilidades (cn)
│   │   ├── App.tsx               # Proveedores globales (QueryClientProvider, Router)
│   │   └── main.tsx              # Punto de entrada de React
│   ├── vite.config.ts            # Configuración de Vite y proxy de desarrollo
│   └── index.html                # Contenedor HTML base
├── server/                       # Backend API Node.js
│   ├── src/
│   │   ├── controllers/          # Manejadores de rutas HTTP
│   │   ├── services/             # Lógica de aplicación
│   │   ├── middlewares/          # Auth, error handling, rate limiting
│   │   ├── db/                   # Esquemas y migraciones SQL
│   │   └── index.ts              # Inicio del servidor Express / Hono
│   └── package.json              # Dependencias del servidor
├── shared/                       # Contratos compartidos y esquemas Zod
├── docker-compose.yml            # PostgreSQL local
└── .env.example                  # Variables de entorno documentadas
```

---

## 3. Reglas de Oro del Stack

1. **Tokens de Sesión en Cookies HTTP-Only**: Prohibido almacenar tokens JWT o credenciales en `localStorage` o `sessionStorage`. Las cookies de sesión se configuran siempre con `httpOnly: true`, `secure: true` (en producción) y `sameSite: 'lax'`.
2. **Proxy de Desarrollo en Vite**: Para evitar problemas de CORS y emular producción idénticamente, el frontend consume `/api` relativo y `vite.config.ts` reenvía las peticiones al puerto del backend.
3. **Estado de Servidor con TanStack Query**: Prohibido usar `useEffect` para fetch manual de datos. Toda consulta asíncrona se gestiona con `useQuery` o `useMutation`, estructurada con fábricas de claves (*Query Key Factory*).
4. **Matriz de 4 Estados Obligatoria**: Todo componente o pantalla que consulta datos debe renderizar explícitamente sus 4 estados: Carga (`aria-busy`), Error (`role="alert"`), Vacío (*Empty state*) y Éxito.
5. **Validación de Contratos Compartidos**: Los DTOs de entrada y salida se validan en el servidor con esquemas Zod definidos en `shared/`, consumidos con tipos inferidos en el cliente.
6. **Separación Estricta de Dependencias**: El código de `client/` **nunca** importa dependencias del servidor (drivers de base de datos, bcrypt, jwt).

---

## 4. Comandos Canónicos

| Acción | Comando |
| :--- | :--- |
| **Base de datos local** | `docker compose up -d` |
| **Dev full-stack** | `npm run dev` (concurrente client + server) |
| **Dev solo cliente** | `cd client && npm run dev` |
| **Dev solo API** | `cd server && npm run dev` |
| **Tests unitarios** | `npm test` (Vitest en cliente y servidor) |
| **Build de producción** | `npm run build` |
| **Pruebas E2E** | `npx playwright test` |

---

## 5. Referencias por Capa (leer la correspondiente)

- **Arquitectura SPA & Proxy**: [spa-architecture.md](references/spa-architecture.md)
- **Estado de Servidor con TanStack Query**: [tanstack-query-state.md](references/tanstack-query-state.md)

---

## 6. Trampas Conocidas (*Gotchas*)

- **Errores de CORS en producción si no hay proxy inverso**: En desarrollo Vite redirige `/api`. En producción, si el frontend y la API están en dominios distintos, se debe configurar CORS estricto en Express con `credentials: true` y lista explícita de orígenes permitidos.
- **Cache Staling con TanStack Query**: Si tras una mutación exitosa no se llama a `queryClient.invalidateQueries({ queryKey: [...] })`, la vista seguirá mostrando datos obsoletos en caché.
- **Variables de entorno de cliente con prefijo `VITE_`**: Solo las variables que empiezan por `VITE_` se inyectan en el cliente (`import.meta.env.VITE_*`). Secretos de servidor **nunca** deben llevar este prefijo.
- **Rutas 404 al recargar en servidores estáticos (SPA Routing)**: Al desplegar la SPA en Nginx, Netlify o Vercel, todas las rutas deben redirigirse a `index.html` (rewrite fallback); de lo contrario, recargar `/dashboard` devolverá un 404 de HTTP.
