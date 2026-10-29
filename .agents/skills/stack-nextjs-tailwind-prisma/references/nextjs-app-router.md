# Guía de Referencia: Next.js App Router & Server Actions

## 1. Principio Fundamental: Server Components por Defecto
En Next.js App Router, todo componente dentro de `app/` es un **React Server Component (RSC)** salvo que se declare explícitamente con `'use client'` en la primera línea.

- **Server Components (por defecto)**:
  - Pueden acceder directamente a bases de datos (`prisma`), secretos de entorno y sistema de archivos.
  - Cero JavaScript adicional en el bundle del cliente.
  - No pueden usar hooks de estado (`useState`, `useReducer`), ciclo de vida (`useEffect`) ni manejadores de eventos DOM (`onClick`, `onChange`).
- **Client Components (`'use client'`)**:
  - Reservados exclusivamente para las "hojas" del árbol de componentes que requieren interactividad, estado local o APIs del navegador.
  - Nunca importes `@prisma/client` o secretos dentro de un Client Component.

## 2. Server Actions Seguras
Toda Server Action debe estar protegida contra accesos no autorizados y validar su entrada con Zod:

```ts
// app/actions/users.ts
'use server';

import { z } from 'zod';
import { prisma } from '@/lib/prisma';
import { auth } from '@/lib/auth';
import { revalidatePath } from 'next/cache';

const UpdateProfileSchema = z.object({
  name: z.string().min(2).max(50),
  bio: z.string().max(200).optional(),
});

export async function updateProfile(data: z.infer<typeof UpdateProfileSchema>) {
  const session = await auth();
  if (!session?.user?.id) {
    throw new Error('UNAUTHORIZED');
  }

  const parsed = UpdateProfileSchema.parse(data);

  const updated = await prisma.user.update({
    where: { id: session.user.id },
    data: parsed,
  });

  revalidatePath('/profile');
  return { success: true, user: updated };
}
```

## 3. Route Handlers (`app/api/`)
Para endpoints REST públicos, webhooks o consumo externo:
- Usa `NextResponse.json(...)`.
- Maneja errores con códigos HTTP adecuados (400, 401, 403, 404, 500).
- Procesa webhooks (Stripe, etc.) leyendo el cuerpo en crudo con `req.text()`.
