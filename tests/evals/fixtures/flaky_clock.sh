#!/usr/bin/env bash
# Fixture: TASK-003 para testing-strategy: test inestable que depende del reloj real y de Math.random.
set -euo pipefail
T=./.agents/scripts/task.sh

$T add "Estabilizar los tests de expiracion de enlaces" "qa-security-agent" \
  "Reloj e id inyectables sin romper la API: createLink(userId, { now, newId } = {}) e isExpired(link, { now } = {}), con Date.now y un id aleatorio por defecto; los tests no usan el reloj real ni aleatoriedad; cubren el limite exacto de expiracion (en expiresAt ya ha caducado); node --test pasa 20 veces seguidas" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p src test
cat > package.json <<'EOF'
{ "name": "links-demo", "type": "module", "scripts": { "test": "node --test" } }
EOF

cat > src/links.js <<'EOF'
// Enlace de restablecimiento que caduca a los 15 minutos.
export const TTL_MS = 15 * 60 * 1000;

export function createLink(userId) {
  return { token: Math.random().toString(36).slice(2), userId, expiresAt: Date.now() + TTL_MS };
}

export function isExpired(link) {
  return Date.now() >= link.expiresAt;
}
EOF

cat > test/links.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createLink, isExpired } from '../src/links.js';

test('un enlace recien creado no ha caducado', () => {
  const link = createLink('u1');
  assert.equal(isExpired(link), false);
});

test('el token tiene longitud estable', () => {
  // Inestable: Math.random().toString(36) no siempre da 11 caracteres
  assert.equal(createLink('u1').token.length, 11);
});

test('caduca pasado el TTL', async () => {
  const link = createLink('u1');
  link.expiresAt = Date.now() + 5;
  await new Promise((r) => setTimeout(r, Math.floor(Math.random() * 10)));
  assert.equal(isExpired(link), true);
});
EOF

git add -A
$T commit TASK-003 "anadir enlaces de restablecimiento" feat >/dev/null
