#!/usr/bin/env bash
# ==============================================================================
# Instalador de Git Hooks del Sistema Multi-Agente
# ==============================================================================

set -e

if [ ! -d ".git" ]; then
  echo "⚠️ Advertencia: No se detectó un repositorio Git activo (.git) en este directorio."
  echo "   Ejecuta 'git init' antes de instalar los hooks."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_SRC="$SCRIPT_DIR/../hooks"
GIT_HOOKS_DIR=".git/hooks"

mkdir -p "$GIT_HOOKS_DIR"

echo "-> Instalando Git Hooks..."
cp "$HOOKS_SRC/commit-msg" "$GIT_HOOKS_DIR/commit-msg"
cp "$HOOKS_SRC/pre-commit" "$GIT_HOOKS_DIR/pre-commit"

chmod +x "$GIT_HOOKS_DIR/commit-msg"
chmod +x "$GIT_HOOKS_DIR/pre-commit"

echo "✅ Git Hooks instalados exitosamente en $GIT_HOOKS_DIR:"
echo "   - commit-msg (Validador de tipo(TASK-XXX): ...)"
echo "   - pre-commit (Escáner de secretos y validador de estado)"
