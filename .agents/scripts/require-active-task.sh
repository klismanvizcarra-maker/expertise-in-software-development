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
# ==============================================================================

[ "${MAESTRO_ALLOW_UNTRACKED:-0}" = "1" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_FILE="$ROOT/GLOBAL_STATE.md"
[ -f "$STATE_FILE" ] || exit 0

FILE=$(python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
i = d.get("tool_input") or {}
print(i.get("file_path") or i.get("notebook_path") or "")
' 2>/dev/null)
[ -n "$FILE" ] || exit 0

# Ruta relativa a la raíz del proyecto (los archivos de fuera no se controlan)
case "$FILE" in
  "$ROOT"/*) REL="${FILE#"$ROOT"/}" ;;
  /*) exit 0 ;;
  *) REL="${FILE#./}" ;;
esac

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
