#!/usr/bin/env bash
# Fixture: TASK-003 en curso para domain-logic-agent: prorrateo con coma flotante y sin casos límite.
set -euo pipefail
T=./.agents/scripts/task.sh

$T add "Prorrateo de cambio de plan en centimos enteros" "domain-logic-agent" \
  "prorate(oldCents, newCents, daysLeft, daysInPeriod) devuelve centimos enteros redondeados a favor del cliente (hacia abajo si cobra, hacia arriba si abona); rechaza dias negativos o daysLeft > daysInPeriod; funcion pura en src/domain; node --test en verde" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p src/domain test
cat > package.json <<'EOF'
{ "name": "proration-demo", "type": "module", "scripts": { "test": "node --test" } }
EOF

cat > src/domain/proration.js <<'EOF'
// Diferencia a cobrar (positiva) o abonar (negativa) al cambiar de plan a mitad de periodo.
export function prorate(oldCents, newCents, daysLeft, daysInPeriod) {
  return (newCents - oldCents) * (daysLeft / daysInPeriod);
}
EOF

cat > test/proration.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { prorate } from '../src/domain/proration.js';

test('periodo completo', () => assert.equal(prorate(1000, 2000, 30, 30), 1000));
EOF

git add -A
$T commit TASK-003 "anadir prorrateo inicial" feat >/dev/null
