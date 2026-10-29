# PostgreSQL 18 + Drizzle — Convenciones

## Esquema (`apps/api/src/db/schema/<tabla>.ts`, reexportado en `index.ts`)
```ts
import { sql } from 'drizzle-orm';
import { pgTable, uuid, text, integer, timestamp, uniqueIndex, index } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: uuid().primaryKey().default(sql`uuidv7()`),
  email: text().notNull(),
  passwordHash: text().notNull(),
  createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
}, (t) => [uniqueIndex('users_email_uq').on(t.email)]);

export const orders = pgTable('orders', {
  id: uuid().primaryKey().default(sql`uuidv7()`),
  userId: uuid().notNull().references(() => users.id, { onDelete: 'cascade' }),
  totalCents: integer().notNull(),
  status: text({ enum: ['pending', 'paid', 'shipped', 'cancelled'] }).notNull().default('pending'),
  createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
}, (t) => [index('orders_user_created_idx').on(t.userId, t.createdAt)]);
```
- Propiedades en camelCase en TypeScript; `casing: 'snake_case'` (en `drizzle.config.ts` **y** en el cliente) las convierte en columnas `snake_case`.
- IDs `uuid` con `uuidv7()` (nativo en PG 18, ordenables por tiempo). Dinero en céntimos `integer` (o `bigint` si puede superar ~21 millones). Fechas siempre `timestamptz`.
- Estados con `text({ enum: [...] })` + `CHECK` cuando la regla sea crítica; evita `pgEnum` si los valores van a cambiar a menudo (alterarlo exige migración especial).
- Toda FK con `onDelete` explícito y su índice.

## Cliente (`db/client.ts`)
```ts
import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from './schema/index.ts';

export const pool = new Pool({ connectionString: env.DATABASE_URL, max: 10, idleTimeoutMillis: 30_000 });
export const db = drizzle({ client: pool, schema, casing: 'snake_case' });
```
Cierra el pool en el apagado (`pool.end()` en `server.ts`) y al final de los tests.

## Migraciones
1. Cambia el esquema TypeScript.
2. `npm run db:generate -w @app/api` → genera `apps/api/drizzle/NNNN_<nombre>.sql`.
3. **Revisa el SQL**: renombres detectados como drop + add, `NOT NULL` sin default sobre tablas con datos, índices sin `CONCURRENTLY` en tablas grandes. Corrige a mano si hace falta (es SQL normal).
4. `npm run db:migrate -w @app/api` sobre una base vacía y sobre una con datos.
5. Commit del `.sql` **y** de `drizzle/meta/` (el historial que usa drizzle-kit).

**Sin `down`**: Drizzle solo avanza. Por eso:
- Revertir = nueva migración correctiva, revisada como cualquier otra.
- Cambios destructivos en varios releases: *expandir* (añadir columna nueva nullable) → *migrar* (backfill por lotes y código que escribe en ambas) → *contraer* (quitar la vieja en un release posterior).
- `drizzle-kit push` solo contra una base local desechable; nunca en staging ni producción.

## Consultas
- Constructor de Drizzle por defecto (`db.select().from(...).where(and(eq(...), ...))`); la API relacional (`db.query.users.findMany({ with: { orders: true } })`) para lecturas con relaciones.
- `sql\`...\`` parametriza las interpolaciones: es seguro. **`sql.raw()` nunca con datos de usuario.**
- Paginación: `limit(Math.min(limit, 100))` + cursor por `(created_at, id)` en listados grandes; `offset` solo en tablas pequeñas.
- Selecciona columnas explícitas en respuestas públicas (nunca devolver `passwordHash`).

## Transacciones
```ts
await db.transaction(async (tx) => {
  const [order] = await tx.insert(orders).values(data).returning();
  await tx.update(users).set({ balanceCents: sql`${users.balanceCents} - ${order.totalCents}` })
    .where(eq(users.id, order.userId));
});
```
Todo lo que toque 2+ tablas va en `db.transaction`; dentro solo se usa `tx`, nunca `db`.

## Rendimiento
- `EXPLAIN (ANALYZE, BUFFERS)` con `docker compose exec db psql -U app -d app` sobre las consultas de listados y filtros.
- Índices compuestos: igualdad primero, rango/orden después (`(user_id, created_at)`).
- Para tablas grandes, `CREATE INDEX CONCURRENTLY` (edita el SQL generado y sepáralo en su propia migración, ya que no puede ir dentro de una transacción).
