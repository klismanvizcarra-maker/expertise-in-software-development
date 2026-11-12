#!/usr/bin/env bash
# ==============================================================================
# Instalador de Git Hooks del Sistema Multi-Agente
# ==============================================================================

set -euo pipefail

PRESERVE_EXISTING=0
case "${1:-}" in
  --preserve-existing) PRESERVE_EXISTING=1 ;;
  "") ;;
  *)
    echo "Uso: ./install-hooks.sh [--preserve-existing]" >&2
    exit 1
    ;;
esac

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
install_hook() {
  local name="$1"
  local src="$HOOKS_SRC/$name"
  local dst="$GIT_HOOKS_DIR/$name"
  if [ "$PRESERVE_EXISTING" -eq 1 ] && [ -e "$dst" ] && ! grep -q '\.agents/scripts/' "$dst" 2>/dev/null; then
    echo "   (se conserva $dst existente; integra manualmente .agents/hooks/$name)"
    return 0
  fi
  cp "$src" "$dst"
  chmod +x "$dst"
}
install_hook commit-msg
install_hook pre-commit

echo "✅ Git Hooks instalados exitosamente en $GIT_HOOKS_DIR:"
echo "   - commit-msg (Validador de tipo(TASK-XXX): ...)"
echo "   - pre-commit (Escáner de secretos y validador de estado)"
