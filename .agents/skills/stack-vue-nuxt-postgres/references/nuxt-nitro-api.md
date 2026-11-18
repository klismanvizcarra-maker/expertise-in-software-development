# Nuxt 3 & Nitro API Reference

Guía técnica para el desarrollo de frontend universal y backend serverless con Nuxt 3 y el motor Nitro.

---

## 1. Handlers de Servidor en Nitro (`server/api/`)

En Nuxt 3, las rutas de servidor residen en `server/api/` o `server/routes/`. Se definen exclusivamente con `defineEventHandler`:

```typescript
// server/api/users/index.get.ts
import { defineEventHandler, getValidatedQuery, createError } from 'h3';
import { z } from 'zod';
import { db } from '~~/server/utils/db';
import { users } from '~~/server/db/schema';

const QuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  cursor: z.string().uuid().optional(),
});

export default defineEventHandler(async (event) => {
  const result = await getValidatedQuery(event, (data) => QuerySchema.safeParse(data));
  if (!result.success) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Bad Request',
      data: { error: 'VALIDATION_ERROR', details: result.error.flatten() },
    });
  }

  const { limit } = result.data;
  const items = await db.select().from(users).limit(limit);

  return { success: true, data: items };
});
```

### Mutaciones con Validación de Cuerpo
```typescript
// server/api/users/index.post.ts
import { defineEventHandler, readValidatedBody, createError } from 'h3';
import { z } from 'zod';
import { db } from '~~/server/utils/db';
import { users } from '~~/server/db/schema';

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
});

export default defineEventHandler(async (event) => {
  const result = await readValidatedBody(event, (body) => CreateUserSchema.safeParse(body));
  if (!result.success) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Bad Request',
      data: { error: 'VALIDATION_ERROR', details: result.error.flatten() },
    });
  }

  const [newUser] = await db.insert(users).values(result.data).returning();
  setResponseStatus(event, 201);
  return { success: true, data: newUser };
});
```

---

## 2. Consumo Reactivo y Prevención de Hydration Mismatches

1. **`useFetch` y `useAsyncData`**:
   En componentes de Vue/Nuxt, **nunca** uses `$fetch` suelto en la raíz de `<script setup>`; eso ejecutaría la petición dos veces (en servidor y en cliente), produciendo errores de deshidratación.
   ```vue
   <script setup lang="ts">
   // ✅ Correcto: uso de useFetch con key única inferida o explícita
   const { data: users, status, error, refresh } = await useFetch('/api/users', {
     key: 'users-list',
     lazy: false,
   });
   </script>
   ```

2. **Evitar variables del navegador en SSR**:
   Objetos como `window`, `document`, `localStorage` o `navigator` no existen en Node/Nitro. Si se acceden en setup, provocan fallo 500:
   ```typescript
   // ✅ Ejecución solo en cliente
   onMounted(() => {
     const theme = localStorage.getItem('theme');
   });
   ```

3. **Cookies Seguras**:
   Utilizar `useCookie` para leer o escribir tokens de sesión de manera transparente tanto en SSR como en el cliente:
   ```typescript
   const authCookie = useCookie('auth_token', {
     httpOnly: true,
     secure: process.env.NODE_ENV === 'production',
     sameSite: 'lax',
     maxAge: 60 * 60 * 24 * 7, // 7 días
   });
   ```
