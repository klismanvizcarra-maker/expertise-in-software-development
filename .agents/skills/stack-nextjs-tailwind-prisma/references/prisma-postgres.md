# Guía de Referencia: PostgreSQL con Prisma ORM

## 1. Configuración del Cliente Singleton
En desarrollo con hot-reload, Next.js reinstancia módulos en cada cambio. Para evitar agotar el pool de conexiones de PostgreSQL:

```ts
// lib/prisma.ts
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ||
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
  });

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
```

## 2. Flujo de Migraciones
- **Desarrollo**:
  ```bash
  npx prisma migrate dev --name <descripcion_en_snake_case>
  ```
  Genera el archivo SQL en `prisma/migrations/`, aplica la migración sobre PostgreSQL y regenera los tipos con `prisma generate`.
- **Producción / CI**:
  ```bash
  npx prisma migrate deploy
  ```
  Aplica únicamente migraciones pendientes sin modificar archivos ni generar diffs. Prohibido ejecutar `prisma db push` en entornos productivos.

## 3. Convenciones de Esquema (`prisma/schema.prisma`)
- Modelos en PascalCase (`model UserAccount`), nombres de tabla mapeados en snake_case (`@@map("user_accounts")`).
- Columnas en camelCase, mapeadas a snake_case (`userId String @map("user_id")`).
- Claves primarias: `String @id @default(uuid())` o `cuid()`.
- Claves foráneas: incluir siempre índice explícito (`@@index([userId])`).
- Marcas temporales: `createdAt DateTime @default(now()) @map("created_at")`, `updatedAt DateTime @updatedAt @map("updated_at")`.
