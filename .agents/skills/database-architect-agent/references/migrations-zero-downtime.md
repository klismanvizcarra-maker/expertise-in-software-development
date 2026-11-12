# Migraciones Zero-Downtime (Expand/Contract), Índices y Planes EXPLAIN

Referencia operativa para PostgreSQL (Drizzle/Prisma/Alembic) y SQLite en proyectos multi-agente.

## 1. Playbook Expand / Contract (cambios sin tiempo de caída)

Cuando conviven réplicas con código antiguo y código nuevo durante un despliegue *rolling* o *blue-green*, un `RENAME COLUMN` o `DROP COLUMN` inmediato rompe las consultas de la versión anterior. Divídelo en **3 migraciones/despliegues separados**:

1. **Fase 1 — Expand (compatible hacia atrás)**:
   - Añade la columna o tabla nueva como `NULL` (sin restricción `NOT NULL` inmediata ni borrar la antigua).
   - Despliega código que **escribe en ambas columnas** (antigua y nueva) y lee primero de la nueva con *fallback* a la antigua.
2. **Fase 2 — Backfill + Restricciones sin bloqueo**:
   - Migra filas históricas en **lotes acotados** (ej. 1 000–5 000 filas por transacción usando keyset por `id` + breve pausa entre lotes) para no saturar I/O, WAL ni retener locks.
   - Si agregas índices sobre tablas vivas grandes, usa `CREATE INDEX CONCURRENTLY` (fuera de bloque `BEGIN...COMMIT`).
   - Si agregas `NOT NULL` o `CHECK` sobre tabla poblada en PostgreSQL: declara primero `CHECK (col IS NOT NULL) NOT VALID` (lock breve en metadatos) y luego `ALTER TABLE ... VALIDATE CONSTRAINT ...` (lock `SHARE UPDATE EXCLUSIVE`, no bloquea lecturas ni escrituras).
3. **Fase 3 — Contract (limpieza final)**:
   - Cuando el 100 % del tráfico corre en código nuevo, despliega la lectura exclusiva de la nueva columna.
   - En una migración posterior, ejecuta `DROP COLUMN` de la columna obsoleta.

## 2. Operaciones DDL Seguras vs Peligrosas en PostgreSQL

| Operación | Riesgo de bloqueo | Alternativa segura zero-downtime |
| :--- | :--- | :--- |
| `RENAME COLUMN` / `DROP COLUMN` | Rompe código antiguo al instante | Expand / Contract en 3 pasos |
| `CREATE INDEX` normal | Bloquea escrituras (`SHARE` lock) | `CREATE INDEX CONCURRENTLY` (fuera de transacción) |
| `ADD CONSTRAINT CHECK / FK` | Escanea toda la tabla con `ACCESS EXCLUSIVE` / `SHARE ROW EXCLUSIVE` | `ADD CONSTRAINT ... NOT VALID` + `VALIDATE CONSTRAINT` |
| `ALTER COLUMN TYPE` | Reescribe la tabla completa con lock exclusivo | Expand (nueva columna con nuevo tipo) → Backfill → Contract |
| `ADD COLUMN col TYPE NOT NULL` sin default | Falla o bloquea si hay filas previas | `ADD COLUMN col TYPE NULL` + Backfill + `CHECK NOT NULL VALIDATE` |

## 3. Checklist de Índices, Integridad y `EXPLAIN`

- **Toda clave foránea lleva índice explícito**: PostgreSQL **no** indexa columnas FK automáticamente; sin índice, `DELETE` o `UPDATE` de PK en la tabla padre puede bloquear/escanear toda la tabla hija.
- **Orden en índices compuestos `(a, b, c)`**: coloca primero columnas de igualdad (`=`), luego columnas de ordenamiento/rango (`ORDER BY`, `>`, `<`). Recuerda que `(tenant_id, created_at DESC, id DESC)` acelera tanto consultas filtradas por `tenant_id` como paginación keyset.
- **Lectura mínima de `EXPLAIN (ANALYZE, BUFFERS)`**:
  - Desconfía de `Seq Scan` en tablas crecientes (> unos miles de filas) con selectividad alta.
  - Revisa `Rows Removed by Filter` muy superior a `actual rows` (falta índice o columna en el orden incorrecto).
  - Verifica `actual time` en entorno realista (no tabla con 5 filas).
- **Concurrencia de inventario / saldos**: nunca hagas `SELECT balance` en código + `if` + `UPDATE balance = balance - x` sin aislamiento; usa actualización condicional atómica (`UPDATE accounts SET balance_cents = balance_cents - :amount WHERE id = :id AND balance_cents >= :amount RETURNING balance_cents`) o `SELECT ... FOR UPDATE`.

