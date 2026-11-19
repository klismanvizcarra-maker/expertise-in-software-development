#!/usr/bin/env bash
# Fixture: Proyecto con documentos de investigación y producto preliminar listo para plan maestro.
set -euo pipefail

mkdir -p docs/research docs/product
cat > docs/research/facturacion.md <<'EOF'
# Investigación: Facturación SaaS B2B
Referentes: Stripe Billing y Facturapi.
Propuesta: API REST modular en Node/Express con PostgreSQL para suscripciones y cobros recurrentes.
EOF

cat > docs/product/prd.md <<'EOF'
# PRD Facturación B2B
MVP: Emisión de facturas, catálogo de planes y clientes, webhooks con firma criptográfica.
EOF

git add -A && git commit -qm "chore(TASK-000): setup inicial para plan maestro" --no-verify
