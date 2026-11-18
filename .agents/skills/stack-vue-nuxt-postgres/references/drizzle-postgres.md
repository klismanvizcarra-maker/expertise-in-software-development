# Drizzle ORM & PostgreSQL Reference (Nuxt 3)

Convenciones para la persistencia de datos relacional con Drizzle ORM y PostgreSQL en Nuxt 3.

---

## 1. Instancia Singleton de Base de Datos (`server/utils/db.ts`)

En Nuxt 3, los archivos en `server/utils/` son importados automáticamente en todos los endpoints de `server/api/`:

```typescript
// server/utils/db.ts
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from '~~/server/db/schema';

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('DATABASE_URL no está definida en las variables de entorno');
}

// En desarrollo se reutiliza la conexión para evitar exceder el pool con HMR
const client = postgres(connectionString, {
  max: process.env.NODE_ENV === 'production' ? 20 : 5,
  idle_timeout: 30,
});

export const db = drizzle(client, { schema });
```

---

## 2. Definición del Esquema (`server/db/schema.ts`)

```typescript
// server/db/schema.ts
import { pgTable, uuid, varchar, text, timestamp } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: uuid('id').defaultRandom().primaryKey(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  name: varchar('name', { length: 100 }).notNull(),
  passwordHash: text('password_hash').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
});

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
```

---

## 3. Configuración de `drizzle.config.ts` y Migraciones

```typescript
// drizzle.config.ts
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './server/db/schema.ts',
  out: './server/db/migrations',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
  verbose: true,
  strict: true,
});
```

### Comandos de Migración
- **Generar migración SQL**: `npx drizzle-kit generate`
- **Aplicar migraciones**: `npx drizzle-kit migrate`
- **Inspección visual (Studio)**: `npx drizzle-kit studio`
