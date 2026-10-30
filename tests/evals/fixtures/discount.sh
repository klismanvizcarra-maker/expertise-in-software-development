#!/usr/bin/env bash
# Fixture: función de descuento con un error de umbral (> en vez de >=) y tests que no lo cubren.
set -euo pipefail
mkdir -p src test
cat > package.json <<'EOF'
{ "name": "discount-demo", "type": "module", "scripts": { "test": "node --test" } }
EOF
cat > src/discount.js <<'EOF'
// 10 % de descuento en pedidos desde 100.
export function applyDiscount(total) {
  return total > 100 ? total * 0.9 : total;
}
EOF
cat > test/discount.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyDiscount } from '../src/discount.js';

test('aplica el 10 % en pedidos grandes', () => assert.equal(applyDiscount(200), 180));
test('no aplica descuento en pedidos pequeños', () => assert.equal(applyDiscount(50), 50));
EOF
git add -A && git commit -qm "feat(TASK-001): calcular descuento" --no-verify
