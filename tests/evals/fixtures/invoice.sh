#!/usr/bin/env bash
# Fixture: cálculo de facturas funcional con lógica duplicada, listo para /refactor.
set -euo pipefail
mkdir -p src test
cat > package.json <<'EOF'
{ "name": "invoice-demo", "type": "module", "scripts": { "test": "node --test" } }
EOF

cat > src/invoice.js <<'EOF'
export function calculateInvoiceTotal(items, region) {
  let subtotal = 0;
  for (const item of items) {
    subtotal += item.price * item.qty;
  }
  if (region === 'ES') {
    const rate = 0.21;
    const tax = Math.round(subtotal * rate);
    return subtotal + tax;
  }
  if (region === 'US') {
    const rate = 0.10;
    const tax = Math.round(subtotal * rate);
    return subtotal + tax;
  }
  if (region === 'FR') {
    const rate = 0.20;
    const tax = Math.round(subtotal * rate);
    return subtotal + tax;
  }
  return subtotal;
}
EOF

cat > test/invoice.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calculateInvoiceTotal } from '../src/invoice.js';

test('calcula IVA ES (21%)', () => assert.equal(calculateInvoiceTotal([{ price: 100, qty: 2 }], 'ES'), 242));
test('calcula tasa US (10%)', () => assert.equal(calculateInvoiceTotal([{ price: 50, qty: 1 }], 'US'), 55));
test('sin tasa en region desconocida', () => assert.equal(calculateInvoiceTotal([{ price: 50, qty: 1 }], 'OTHER'), 50));
EOF

git add -A && git commit -qm "feat(TASK-001): calcular totales de factura" --no-verify

