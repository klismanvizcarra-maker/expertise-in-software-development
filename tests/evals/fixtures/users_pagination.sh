#!/usr/bin/env bash
# Fixture: TASK-003 en curso para backend-agent: GET /users sin paginación ni validación de entrada.
set -euo pipefail
T=./.agents/scripts/task.sh

$T add "Paginar y validar GET /api/v1/users" "backend-agent" \
  "listUsers acepta limit (1-100, por defecto 20) y cursor; rechaza limit fuera de rango o no numerico con error 400 VALIDATION_ERROR; devuelve { data, nextCursor }; node --test en verde" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p src test
cat > package.json <<'EOF'
{ "name": "users-demo", "type": "module", "scripts": { "test": "node --test" } }
EOF

cat > src/users.js <<'EOF'
// Controlador de GET /api/v1/users. users: array ordenado por id ascendente.
// Devuelve { status, body } como lo serializaria el framework HTTP.
export function listUsers(users, query = {}) {
  return { status: 200, body: { data: users } };
}
EOF

cat > test/users.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { listUsers } from '../src/users.js';

const users = Array.from({ length: 3 }, (_, i) => ({ id: i + 1, name: `u${i + 1}` }));

test('lista usuarios', () => {
  const res = listUsers(users, {});
  assert.equal(res.status, 200);
  assert.ok(Array.isArray(res.body.data));
});
EOF

git add -A
$T commit TASK-003 "anadir listado inicial de usuarios" feat >/dev/null
