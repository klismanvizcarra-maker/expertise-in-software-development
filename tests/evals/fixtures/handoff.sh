#!/usr/bin/env bash
# Fixture: TASK-003 implementada y con tests en verde, lista para /handoff.
set -euo pipefail
T=./.agents/scripts/task.sh

$T add "Validacion de cupones de descuento" "backend-agent" \
  "applyCoupon aplica 20% con PROMO20 y rechaza codigo invalido; node --test en verde" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p src test
cat > package.json <<'EOF'
{ "name": "coupon-demo", "type": "module", "scripts": { "test": "node --test" } }
EOF

cat > src/coupon.js <<'EOF'
export function applyCoupon(total, code) {
  if (code !== 'PROMO20') throw new Error('COUPON_INVALID');
  return Math.round(total * 0.8);
}
EOF

cat > test/coupon.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyCoupon } from '../src/coupon.js';

test('aplica 20% con PROMO20', () => assert.equal(applyCoupon(100, 'PROMO20'), 80));
test('rechaza cupon invalido', () => assert.throws(() => applyCoupon(100, 'NOPE'), /COUPON_INVALID/));
EOF

git add package.json src test
$T commit TASK-003 "implementar validacion de cupones" feat >/dev/null

