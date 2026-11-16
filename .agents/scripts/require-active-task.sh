#!/usr/bin/env bash
# ==============================================================================
# Hook PreToolUse de Claude Code: "Cero Código sin Tarea" (AGENTS.md §2.4)
# ==============================================================================
# Bloquea Edit/Write/MultiEdit/NotebookEdit sobre archivos de código si no hay
# ninguna tarea IN_PROGRESS en GLOBAL_STATE.md. Se configura en
# .claude/settings.json (plantilla: .agents/templates/claude_settings_template.json).
#
# Siempre permitidos: Markdown, docs/, specs/, .agents/, .claude/ y archivos
# fuera del proyecto. Sin GLOBAL_STATE.md (proyecto sin iniciar) no actúa.
# Escape puntual: MAESTRO_ALLOW_UNTRACKED=1 en el entorno de Claude Code.
#
# Entrada: JSON del hook por stdin. Salida: exit 0 = permitir, exit 2 = bloquear
# (el mensaje de stderr llega al modelo).
#
# Nota sobre flags de shell:
# Como hook de pre-herramienta de Claude Code, no usa 'set -e' para asegurar que
# fallos imprevistos no aborten el entorno del agente y para garantizar que cualquier
# bloqueo emita un mensaje limpio por stderr con código de salida 2 (fail-closed).
# ==============================================================================

[ "${MAESTRO_ALLOW_UNTRACKED:-0}" = "1" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_FILE="$ROOT/GLOBAL_STATE.md"
[ -f "$STATE_FILE" ] || exit 0

if ! command -v python3 >/dev/null 2>&1; then
  printf 'Bloqueado por AGENTS.md §2.4 (Cero Código sin Tarea): se requiere python3 para validar la tarea activa.\nInstala python3 en tu entorno para permitir la edición de archivos.\n' >&2
  exit 2
fi

# Ruta relativa a la raíz del proyecto, normalizada: sin segmentos '.' ni '..' (así
# '.agents/../src/app.ts' no pasa por una ruta exenta) y las relativas se resuelven contra
# la raíz. Vacía si el archivo queda fuera del proyecto (no se controla).
REL=$(ROOT="$ROOT" python3 -c '
import json, os, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
i = d.get("tool_input") or {}
path = i.get("file_path") or i.get("notebook_path") or ""
if not isinstance(path, str) or not path or "\n" in path or "\r" in path:
    sys.exit(0)
root = os.path.normpath(os.environ["ROOT"])
full = os.path.normpath(path if os.path.isabs(path) else os.path.join(root, path))
rel = os.path.relpath(full, root)
if rel == "." or rel == ".." or rel.startswith(".." + os.sep):
    sys.exit(0)
print(rel)
' 2>/dev/null)
[ -n "$REL" ] || exit 0

case "$REL" in
  *.md|docs/*|specs/*|.agents/*|.claude/*) exit 0 ;;
esac

ACTIVE=$(awk -F'|' '
  /^\|/ {
    id = $2; gsub(/[ \t`]/, "", id)
    st = $5; gsub(/[ \t`]/, "", st)
    if (id ~ /^TASK-[0-9]+$/ && st == "IN_PROGRESS") print id
  }
' "$STATE_FILE")

[ -n "$ACTIVE" ] && exit 0

cat >&2 <<EOF
Bloqueado por AGENTS.md §2.4 (Cero Código sin Tarea): no hay ninguna TASK-XXX en IN_PROGRESS en GLOBAL_STATE.md, así que no se puede editar $REL.
Registra la tarea con /nueva-tarea (o /bugfix si es un error) y empiézala con ./.agents/scripts/task.sh start TASK-XXX antes de modificar código.
EOF
exit 2
