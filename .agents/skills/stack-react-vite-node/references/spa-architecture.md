# React + Vite + Node Architecture Reference

Convenciones de arquitectura para Single Page Applications (SPA) con React 19, Vite y servidor Node.js/Express.

---

## 1. Estructura Cliente/Servidor y Proxy de Desarrollo

En proyectos SPA, el cliente corre en el navegador y el servidor API corre como proceso Node independiente.

```text
<proyecto>/
├── client/                       # SPA React con Vite
│   ├── src/
│   │   ├── components/ui/        # Componentes base accesibles
│   │   ├── features/             # Módulos por dominio (auth, users, billing)
│   │   │   ├── components/
│   │   │   ├── hooks/
│   │   │   └── api/
│   │   ├── layouts/
│   │   ├── routes/               # Enrutamiento React Router / TanStack Router
│   │   └── App.tsx
│   ├── vite.config.ts            # Proxy y plugins de Vite
│   └── index.html
├── server/                       # API Node.js (Express o Hono)
│   ├── src/
│   │   ├── controllers/
│   │   ├── routes/
│   │   ├── middlewares/
│   │   └── db/
│   └── server.ts
└── shared/                       # Contratos y tipos compartidos (Zod schemas)
```

### Configuración del Proxy en `client/vite.config.ts`
Para evitar problemas de CORS en desarrollo:

```typescript
// client/vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:4000',
        changeOrigin: true,
      },
    },
  },
});
```

---

## 2. Autenticación Segura (JWT en Cookies HTTP-Only)

**Regla de Oro**: Prohibido almacenar tokens de sesión o JWT en `localStorage` o `sessionStorage`, ya que cualquier script inyectado (XSS) puede extraerlos.

1. **En Servidor (`server/`)**:
   Emitir el token en una cookie `httpOnly`, `secure`, `sameSite: 'lax'`:
   ```typescript
   res.cookie('token', jwtToken, {
     httpOnly: true,
     secure: process.env.NODE_ENV === 'production',
     sameSite: 'lax',
     maxAge: 7 * 24 * 60 * 60 * 1000,
   });
   ```

2. **En Cliente (`client/`)**:
   Configurar el cliente HTTP (Fetch API o Axios) para incluir credenciales:
   ```typescript
   // client/src/lib/api-client.ts
   export async function apiFetch<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
     const res = await fetch(`/api${endpoint}`, {
       ...options,
       credentials: 'include',
       headers: {
         'Content-Type': 'application/json',
         ...options.headers,
       },
     });
     if (!res.ok) {
       const err = await res.json().catch(() => ({}));
       throw new Error(err.message || 'Error en la petición');
     }
     return res.json();
   }
   ```
