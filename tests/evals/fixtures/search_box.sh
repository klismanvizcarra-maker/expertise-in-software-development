#!/usr/bin/env bash
# Fixture: TASK-003 en curso para frontend-agent: vista de resultados sin estados de carga, vacío ni error.
set -euo pipefail
T=./.agents/scripts/task.sh

$T add "Vista de resultados de busqueda con sus 4 estados" "frontend-agent" \
  "renderResults(state) devuelve HTML para loading (aria-busy), empty (mensaje), error (role=alert con boton Reintentar) y success (lista); escapa el texto de los resultados; node --test en verde" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p src test
cat > package.json <<'EOF'
{ "name": "search-ui-demo", "type": "module", "scripts": { "test": "node --test" } }
EOF

cat > src/results.js <<'EOF'
// Renderiza la vista de resultados. state = { status: 'loading'|'empty'|'error'|'success', items?: [{ title }], message?: string }
export function renderResults(state) {
  return '<ul>' + (state.items || []).map((i) => '<li>' + i.title + '</li>').join('') + '</ul>';
}
EOF

cat > test/results.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderResults } from '../src/results.js';

test('pinta los resultados', () => {
  const html = renderResults({ status: 'success', items: [{ title: 'Uno' }] });
  assert.ok(html.includes('Uno'));
});
EOF

git add -A
$T commit TASK-003 "anadir vista inicial de resultados" feat >/dev/null
