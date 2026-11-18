#!/usr/bin/env bash
# Fixture: TASK-003 en curso para async-jobs: worker de emails que reenvía en cada entrega y reintenta sin control.
set -euo pipefail
T=./.agents/scripts/task.sh

$T add "Worker de emails idempotente con reintentos" "backend-agent" \
  "handleMessage(msg, deps) no reenvia un email si el mismo msg.id ya se envio con exito; un fallo de envio no marca el mensaje como procesado; ante fallo transitorio reintenta (queue.retry) con computeBackoff: exponencial, con jitter y con un tope; tras maxAttempts envia a la DLQ; node --test en verde" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p src test
cat > package.json <<'EOF'
{ "name": "email-worker-demo", "type": "module", "scripts": { "test": "node --test" } }
EOF

cat > src/worker.js <<'EOF'
// Consumidor de la cola "emails". La cola entrega cada mensaje al menos una vez.
// msg = { id, attempt, to, template }
// deps = { mailer: { send(to, template) }, store: { has(id), add(id) }, queue: { retry(msg, delayMs), deadLetter(msg, error) }, maxAttempts }
export async function handleMessage(msg, deps) {
  await deps.mailer.send(msg.to, msg.template);
}

// Espera antes del reintento número `attempt` (1, 2, 3...), en milisegundos.
export function computeBackoff(attempt, random = Math.random) {
  return 1000;
}
EOF

cat > test/worker.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleMessage } from '../src/worker.js';

test('envia el email', async () => {
  const sent = [];
  const deps = { mailer: { send: async (to) => sent.push(to) }, store: { has: () => false, add() {} }, queue: { retry() {}, deadLetter() {} }, maxAttempts: 5 };
  await handleMessage({ id: 'm1', attempt: 1, to: 'a@x.com', template: 'welcome' }, deps);
  assert.deepEqual(sent, ['a@x.com']);
});
EOF

git add -A
$T commit TASK-003 "anadir worker de emails inicial" feat >/dev/null
