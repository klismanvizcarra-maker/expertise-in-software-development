#!/usr/bin/env bash
# Fixture: TASK-003 en progreso con consulta SQL concatenada e IDOR, listo para /security-hardening.
set -euo pipefail
T=./.agents/scripts/task.sh

$T add "Endurecer busqueda de facturas" "backend-agent" \
  "Consulta parametrizada sin concatenacion SQL; solo devuelve facturas del authUserId autenticado; node --test en verde" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p src test
cat > package.json <<'EOF'
{ "name": "search-demo", "type": "module", "scripts": { "test": "node --test" } }
EOF

cat > src/search.js <<'EOF'
export function searchInvoices(db, authUserId, params) {
  const sql = "SELECT id, total FROM invoices WHERE user_id = '" + params.userId + "' AND status = '" + params.status + "'";
  return db.query(sql, []);
}
EOF

cat > test/search.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { searchInvoices } from '../src/search.js';

test('devuelve consulta de facturas para el usuario', () => {
  let captured = '';
  const db = { query: (sql) => { captured = sql; return [{ id: 'inv-1', total: 100 }]; } };
  const rows = searchInvoices(db, 'u1', { userId: 'u1', status: 'paid' });
  assert.equal(rows.length, 1);
  assert.ok(captured.includes('invoices'));
});
EOF

git add -A
$T commit TASK-003 "anadir busqueda inicial de facturas" feat >/dev/null

