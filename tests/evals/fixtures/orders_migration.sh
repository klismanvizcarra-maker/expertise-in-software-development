#!/usr/bin/env bash
# Fixture: TASK-003 en curso para database-architect-agent: consulta lenta por falta de índice en la FK.
set -euo pipefail
T=./.agents/scripts/task.sh

$T add "Indice para la consulta de pedidos por cliente" "database-architect-agent" \
  "Nueva migracion versionada (no editar las existentes) que crea un indice sobre orders(customer_id, created_at) con su down que lo elimina; la migracion 0001 queda intacta" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p migrations
cat > migrations/0001_create_orders.up.sql <<'EOF'
CREATE TABLE orders (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT NOT NULL REFERENCES customers(id),
  total_cents INTEGER NOT NULL CHECK (total_cents >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
EOF
cat > migrations/0001_create_orders.down.sql <<'EOF'
DROP TABLE orders;
EOF
cat > QUERIES.md <<'EOF'
# Consulta lenta

    SELECT id, total_cents FROM orders
    WHERE customer_id = $1
    ORDER BY created_at DESC
    LIMIT 20;

EXPLAIN muestra un Seq Scan sobre orders (12 millones de filas).
EOF

git add -A
$T commit TASK-003 "documentar consulta lenta de pedidos" docs >/dev/null
