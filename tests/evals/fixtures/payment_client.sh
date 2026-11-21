#!/usr/bin/env bash
# Fixture: TASK-003 en curso para resilience-engineering: llamada a la pasarela de pagos sin timeout, sin reintentos y sin circuit breaker.
set -euo pipefail
T=./.agents/scripts/task.sh

$T add "Llamadas resilientes a la pasarela de pagos" "backend-agent" \
  "createResilientCaller(opts).call(fn) en src/resilient.js: cada intento que no termina en timeoutMs falla con err.code ETIMEDOUT; reintenta solo fallos transitorios (code ETIMEDOUT, ECONNRESET o ECONNREFUSED, o status 429 o >= 500) hasta maxRetries veces, esperando con opts.sleep un backoff exponencial desde baseDelayMs con jitter (opts.random) y tope maxDelayMs; un 4xx distinto de 429 se relanza sin reintentar; circuit breaker: failureThreshold llamadas seguidas que acaban en fallo transitorio tras agotar sus reintentos lo abren (cuenta llamadas, no intentos; un exito reinicia la cuenta; un 4xx no cuenta) y mientras esta abierto call() rechaza al instante con err.code CIRCUIT_OPEN sin invocar fn; pasado cooldownMs segun opts.now deja pasar una sola llamada de prueba (mientras esta en curso, las demas rechazan con CIRCUIT_OPEN): si va bien se cierra y si falla se vuelve a abrir; state() devuelve CLOSED, OPEN o HALF_OPEN; sin dependencias nuevas (no hay red); tests con node:test que usen createResilientCaller y cubran timeout, reintentos y breaker; node --test en verde" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p src test
cat > package.json <<'EOF'
{ "name": "payments-demo", "type": "module", "scripts": { "test": "node --test" } }
EOF

cat > src/resilient.js <<'EOF'
// Envuelve las llamadas a servicios externos (pasarela de pagos).
// opts = { timeoutMs, maxRetries, baseDelayMs, maxDelayMs, failureThreshold, cooldownMs, now, sleep, random }
export function createResilientCaller(opts = {}) {
  return {
    async call(fn) {
      return fn();
    },
    state() {
      return 'CLOSED';
    },
  };
}
EOF

cat > src/payments.js <<'EOF'
import { createResilientCaller } from './resilient.js';

const gateway = createResilientCaller({ timeoutMs: 2000, maxRetries: 3, baseDelayMs: 100, maxDelayMs: 2000, failureThreshold: 5, cooldownMs: 30000 });

export function charge(http, payload) {
  return gateway.call(() => http.post('/charges', payload));
}
EOF

cat > test/resilient.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createResilientCaller } from '../src/resilient.js';

test('devuelve el resultado de fn', async () => {
  const caller = createResilientCaller();
  assert.equal(await caller.call(async () => 'ok'), 'ok');
});
EOF

git add -A
$T commit TASK-003 "anadir cliente de pagos sin proteccion ante fallos" feat >/dev/null
