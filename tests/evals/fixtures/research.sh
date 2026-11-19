#!/usr/bin/env bash
# Fixture: Proyecto inicial con intención de explorar referentes de movilidad urbana.
set -euo pipefail

mkdir -p docs
cat > README.md <<'EOF'
# Movilidad Urbana Demo
Plataforma de transporte de pasajeros para competir con Uber y Cabify en el mercado local.
EOF

git add -A && git commit -qm "chore(TASK-000): setup inicial para research" --no-verify
