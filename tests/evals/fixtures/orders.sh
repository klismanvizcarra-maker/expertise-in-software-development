#!/usr/bin/env bash
# Fixture: TASK-003 "Endpoint GET /orders/:id" entregada a QA (IN_REVIEW_QA).
# Uso: bash orders.sh idor   → la implementación no comprueba el propietario (debe rechazarse)
#      bash orders.sh ok     → implementación correcta con test del caso ajeno (debe aprobarse)
set -euo pipefail
VARIANT="${1:-idor}"
T=./.agents/scripts/task.sh

$T add "Endpoint GET /api/v1/orders/:id" "backend-agent" \
  "Devuelve el pedido pedido por su dueño; un usuario nunca lee pedidos ajenos (null/404); node --test en verde" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p src test
cat > package.json <<'EOF'
{ "name": "orders-demo", "type": "module", "scripts": { "test": "node --test" } }
EOF

if [ "$VARIANT" = "ok" ]; then
cat > src/orders.js <<'EOF'
// Devuelve el pedido solo si pertenece al usuario autenticado; si no, null (la ruta responde 404).
export function getOrder(orders, userId, orderId) {
  return orders.find((o) => o.id === orderId && o.userId === userId) ?? null;
}
EOF
cat > test/orders.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getOrder } from '../src/orders.js';

const orders = [{ id: 'o1', userId: 'u1', total: 1000 }, { id: 'o2', userId: 'u2', total: 500 }];

test('el dueño lee su pedido', () => assert.equal(getOrder(orders, 'u1', 'o1').total, 1000));
test('un usuario no lee pedidos ajenos', () => assert.equal(getOrder(orders, 'u1', 'o2'), null));
test('pedido inexistente', () => assert.equal(getOrder(orders, 'u1', 'nope'), null));
EOF
else
cat > src/orders.js <<'EOF'
// Devuelve el pedido por id (la ruta responde 404 si es null).
export function getOrder(orders, userId, orderId) {
  return orders.find((o) => o.id === orderId) ?? null;
}
EOF
cat > test/orders.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getOrder } from '../src/orders.js';

const orders = [{ id: 'o1', userId: 'u1', total: 1000 }, { id: 'o2', userId: 'u2', total: 500 }];

test('el dueño lee su pedido', () => assert.equal(getOrder(orders, 'u1', 'o1').total, 1000));
test('pedido inexistente', () => assert.equal(getOrder(orders, 'u1', 'nope'), null));
EOF
fi

git add package.json src test
$T commit TASK-003 "implementar lectura de pedido por id" feat >/dev/null
$T handoff TASK-003 >/dev/null
git add -A && git commit -qm "chore(TASK-003): registrar entrega a QA"
