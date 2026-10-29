#!/usr/bin/env bash
# ==============================================================================
# Script de Inicialización de Nuevos Proyectos Multi-Agente
# Instala el sistema para Antigravity (.agents/ + AGENTS.md) y Claude Code
# (.claude/skills + CLAUDE.md + .mcp.json) desde una única fuente.
# ==============================================================================
# Uso:
#   ./init-project.sh "Mi Proyecto" "/ruta/al/nuevo/proyecto" [--copy]
#   O simplemente: ./init-project.sh "Mi Proyecto"
#
#   --copy  Copia las skills en .claude/skills en vez de crear un enlace
#           simbólico (útil en Windows o si el repositorio no admite symlinks).
# ==============================================================================

set -e

PROJECT_NAME="${1:-Nuevo Proyecto}"
TARGET_DIR="${2:-.}"
LINK_MODE="symlink"
[ "$3" = "--copy" ] && LINK_MODE="copy"
CURRENT_DATE=$(date +"%Y-%m-%d")

# Directorio donde se encuentra este script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Copia un archivo solo si no existe en el destino (nunca sobrescribe trabajo previo)
copy_if_missing() {
  if [ -e "$2" ]; then
    echo "   (se conserva $2 existente)"
  else
    cp "$1" "$2"
  fi
}

echo "================================================================="
echo "  Inicializando Entorno Multi-Agente para: $PROJECT_NAME"
echo "  Directorio de destino: $TARGET_DIR"
echo "================================================================="

# Crear carpetas en el destino si no existen
mkdir -p "$TARGET_DIR/.agents/skills"
mkdir -p "$TARGET_DIR/.agents/templates"
mkdir -p "$TARGET_DIR/.agents/scripts"
mkdir -p "$TARGET_DIR/.agents/brain"
mkdir -p "$TARGET_DIR/.agents/hooks"
mkdir -p "$TARGET_DIR/.agents/plugins"
mkdir -p "$TARGET_DIR/docs/product"

# Copiar skills, templates, brain, scripts, hooks y plugins
echo "-> Copiando catalogo de skills, plantillas y modulos de memoria..."
cp -R "$SKILL_ROOT/.agents/skills/"* "$TARGET_DIR/.agents/skills/"
cp -R "$SKILL_ROOT/.agents/templates/"* "$TARGET_DIR/.agents/templates/"
cp -R "$SKILL_ROOT/.agents/scripts/"* "$TARGET_DIR/.agents/scripts/"
cp -R "$SKILL_ROOT/.agents/hooks/"* "$TARGET_DIR/.agents/hooks/"
cp -R "$SKILL_ROOT/.agents/plugins/"* "$TARGET_DIR/.agents/plugins/"

# Dar permisos de ejecución
chmod +x "$TARGET_DIR/.agents/scripts/"*.sh 2>/dev/null || true
chmod +x "$TARGET_DIR/.agents/hooks/"* 2>/dev/null || true

# Reglas globales: AGENTS.md (Antigravity) + CLAUDE.md que lo importa (Claude Code)
echo "-> Instalando reglas maestras AGENTS.md y CLAUDE.md..."
copy_if_missing "$SKILL_ROOT/AGENTS.md" "$TARGET_DIR/AGENTS.md"
if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
  if ! grep -q '^@AGENTS.md' "$TARGET_DIR/CLAUDE.md"; then
    printf '\n@AGENTS.md\n' >> "$TARGET_DIR/CLAUDE.md"
    echo "   (se añadió @AGENTS.md al CLAUDE.md existente)"
  fi
else
  cp "$SKILL_ROOT/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
fi

# Skills para Claude Code: enlace a la fuente única .agents/skills
echo "-> Conectando skills con Claude Code (.claude/skills, modo: $LINK_MODE)..."
mkdir -p "$TARGET_DIR/.claude"
if [ -L "$TARGET_DIR/.claude/skills" ] || [ ! -e "$TARGET_DIR/.claude/skills" ]; then
  rm -f "$TARGET_DIR/.claude/skills"
  if [ "$LINK_MODE" = "symlink" ]; then
    ln -s ../.agents/skills "$TARGET_DIR/.claude/skills"
  else
    cp -R "$TARGET_DIR/.agents/skills" "$TARGET_DIR/.claude/skills"
  fi
else
  # Ya existe una carpeta real con skills propias: añadir las del sistema sin borrar nada
  cp -R "$TARGET_DIR/.agents/skills/"* "$TARGET_DIR/.claude/skills/"
fi

# Servidores MCP: .mcp.json (Claude Code). Antigravity los toma del plugin maestro-mcp.
echo "-> Instalando configuracion MCP (.mcp.json)..."
copy_if_missing "$SKILL_ROOT/.agents/templates/mcp_config_template.json" "$TARGET_DIR/.mcp.json"

# Hook de Claude Code que exige una tarea IN_PROGRESS antes de editar código (AGENTS.md §2.4)
echo "-> Instalando hook 'Cero Código sin Tarea' (.claude/settings.json)..."
if [ -e "$TARGET_DIR/.claude/settings.json" ]; then
  echo "   (se conserva .claude/settings.json existente: añade a mano el hook de"
  echo "    .agents/templates/claude_settings_template.json)"
else
  cp "$SKILL_ROOT/.agents/templates/claude_settings_template.json" "$TARGET_DIR/.claude/settings.json"
fi

# Copiar .gitignore y .env.example
echo "-> Instalando .gitignore y .env.example..."
copy_if_missing "$SKILL_ROOT/.gitignore" "$TARGET_DIR/.gitignore"
copy_if_missing "$SKILL_ROOT/.agents/templates/env_template.example" "$TARGET_DIR/.env.example"

# Crear GLOBAL_STATE.md a partir de la plantilla
if [ -f "$TARGET_DIR/GLOBAL_STATE.md" ]; then
  echo "-> GLOBAL_STATE.md ya existe; se conserva."
else
  echo "-> Generando GLOBAL_STATE.md configurado..."
  sed -e "s|\[NOMBRE_DEL_PROYECTO\]|$PROJECT_NAME|g" \
      -e "s|YYYY-MM-DD|$CURRENT_DATE|g" \
      "$SKILL_ROOT/.agents/templates/GLOBAL_STATE_TEMPLATE.md" > "$TARGET_DIR/GLOBAL_STATE.md"
fi

# Crear BRAIN.md y los módulos de memoria sin sobrescribir lo que el proyecto ya aprendió.
# En archivos nuevos se eliminan las filas de ejemplo (LL-/TD-) para empezar con IDs limpios.
echo "-> Inicializando BRAIN.md y .agents/brain/ (Memoria a Largo Plazo)..."
strip_examples() {
  local tmp
  tmp=$(mktemp)
  grep -vE '^\|[ \t]*`?(LL|TD)-[0-9]+' "$1" > "$tmp" || true
  mv "$tmp" "$1"
}
install_brain_file() {
  if [ -e "$2" ]; then
    echo "   (se conserva $2 existente)"
  else
    cp "$1" "$2"
    strip_examples "$2"
  fi
}
install_brain_file "$SKILL_ROOT/.agents/templates/BRAIN_TEMPLATE.md" "$TARGET_DIR/BRAIN.md"
for f in "$SKILL_ROOT/.agents/brain/"*.md; do
  install_brain_file "$f" "$TARGET_DIR/.agents/brain/$(basename "$f")"
done

# Generar README.md si no existe en el destino
if [ ! -f "$TARGET_DIR/README.md" ]; then
  echo "-> Generando README.md del proyecto..."
  sed -e "s|\[NOMBRE_DEL_PROYECTO\]|$PROJECT_NAME|g" \
      "$SKILL_ROOT/.agents/templates/README_TEMPLATE.md" > "$TARGET_DIR/README.md"
fi

# Instalar Git hooks si existe .git
if [ -d "$TARGET_DIR/.git" ]; then
  echo "-> Instalando Git Hooks en repositorio local..."
  (cd "$TARGET_DIR" && bash ./.agents/scripts/install-hooks.sh) || true
fi

echo "================================================================="
echo "  [OK] Inicializacion completada exitosamente!"
echo ""
echo "  Archivos generados:"
echo "    - $TARGET_DIR/AGENTS.md (Reglas globales; Antigravity)"
echo "    - $TARGET_DIR/CLAUDE.md (Importa AGENTS.md; Claude Code)"
echo "    - $TARGET_DIR/.claude/skills (Skills para Claude Code -> .agents/skills)"
echo "    - $TARGET_DIR/.mcp.json (Servidores MCP; Claude Code)"
echo "    - $TARGET_DIR/.claude/settings.json (Hook: cero codigo sin tarea; Claude Code)"
echo "    - $TARGET_DIR/.agents/plugins/maestro-mcp/ (Servidores MCP; Antigravity)"
echo "    - $TARGET_DIR/GLOBAL_STATE.md (Unica Fuente de Verdad SSOT)"
echo "    - $TARGET_DIR/BRAIN.md (Cerebro y Memoria Persistente)"
echo "    - $TARGET_DIR/.agents/scripts/task.sh (CLI de gestion de tareas)"
echo ""
command -v npx >/dev/null 2>&1 || {
  echo "  [AVISO] 'npx' no esta instalado: el MCP web-tester-playwright no arrancara."
  echo "          Instala Node.js LTS."
  echo ""
}
echo "  Siguiente paso:"
echo "    Abre el proyecto en Claude Code o Antigravity y dale tu primer"
echo "    requerimiento al Orchestrator Agent (/orchestrator-agent)."
echo "================================================================="
