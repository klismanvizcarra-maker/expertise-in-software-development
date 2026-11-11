#!/usr/bin/env bash
# ==============================================================================
# Hook PreToolUse de Claude Code: el cerebro va al agente (AGENTS.md §7.4)
# ==============================================================================
# Cuando el agente va a editar un archivo cuya ruta coincide con el Ámbito de una
# lección ACTIVA (.agents/brain/lessons_learned.md), le muestra esa lección como
# contexto adicional. Nunca bloquea: siempre sale con código 0.
#
# - Cada lección se muestra una sola vez por sesión (registro en el directorio
#   temporal del usuario, por session_id).
# - Las lecciones generales (ámbito `*`) no se inyectan aquí: se ven con
#   'task.sh start' y 'task.sh brain for TASK-XXX'.
# - Desactivar puntualmente: MAESTRO_BRAIN_CONTEXT=0 en el entorno de Claude Code.
#
# Entrada: JSON del hook por stdin. Salida: JSON con
# hookSpecificOutput.additionalContext (o nada si no hay lecciones que mostrar).
#
# Nota sobre flags de shell:
# No usa 'set -e': cualquier fallo imprevisto debe terminar en silencio y con
# código 0, porque este hook es informativo y jamás debe impedir una edición.
# ==============================================================================

[ "${MAESTRO_BRAIN_CONTEXT:-1}" = "0" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
BRAIN_FILE="$ROOT/BRAIN.md"
LL_FILE="$ROOT/.agents/brain/lessons_learned.md"
DEBT_FILE="$ROOT/.agents/brain/tech_debt.md"
STATE_FILE="$ROOT/GLOBAL_STATE.md"
[ -f "$LL_FILE" ] || [ -f "$BRAIN_FILE" ] || exit 0

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/brain-lib.sh"
[ -f "$LIB" ] || exit 0
die() { exit 0; }
replace_file() { :; }
# shellcheck source=brain-lib.sh
. "$LIB" 2>/dev/null || exit 0

INPUT=$(cat)
PARSED=$(printf '%s' "$INPUT" | python3 -c '
import json, re, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
i = d.get("tool_input") or {}
path = i.get("file_path") or i.get("notebook_path") or ""
sid = re.sub(r"[^A-Za-z0-9_-]", "", str(d.get("session_id") or ""))[:80]
if "\n" in path or "\r" in path:
    sys.exit(0)
print(sid)
print(path)
' 2>/dev/null)
SESSION=$(printf '%s\n' "$PARSED" | sed -n 1p)
FILE=$(printf '%s\n' "$PARSED" | sed -n 2p)
[ -n "$FILE" ] || exit 0

# Solo archivos del proyecto
case "$FILE" in
  "$ROOT"/*) REL="${FILE#"$ROOT"/}" ;;
  /*) exit 0 ;;
  *) REL="${FILE#./}" ;;
esac

# Lecciones activas cuyo ámbito cubre la ruta (sin categoría ni texto de tarea)
HITS=$(relevant_lessons "" "" "$REL" 2>/dev/null)
[ -n "$HITS" ] || exit 0

# Una vez por lección y sesión
SEEN_FILE=""
if [ -n "$SESSION" ]; then
  SEEN_DIR="${TMPDIR:-/tmp}/maestro-brain-context"
  mkdir -p "$SEEN_DIR" 2>/dev/null && SEEN_FILE="$SEEN_DIR/$SESSION"
fi
NEW=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  id="${line%%$'\t'*}"
  if [ -n "$SEEN_FILE" ] && [ -f "$SEEN_FILE" ] && grep -qxF "$id" "$SEEN_FILE" 2>/dev/null; then
    continue
  fi
  NEW="${NEW}${line}"$'\n'
  [ -n "$SEEN_FILE" ] && printf '%s\n' "$id" >> "$SEEN_FILE" 2>/dev/null
done <<< "$HITS"
[ -n "$NEW" ] || exit 0

HITS_NEW="$NEW" REL="$REL" python3 -c '
import json, os
rel = os.environ["REL"]
out = ["Cerebro del proyecto: lecciones aprendidas que aplican a " + rel + " (revísalas antes de editar):"]
for line in os.environ["HITS_NEW"].split("\n"):
    if not line:
        continue
    f = line.split("\t")
    if len(f) < 5:
        continue
    out.append("- %s [%s] %s" % (f[0], f[1], f[2]))
    out.append("  Antídoto: %s" % f[4])
out.append("Detalle: .agents/brain/lessons_learned.md · Consulta dirigida: ./.agents/scripts/task.sh brain for TASK-XXX <ruta>")
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "\n".join(out)}}, ensure_ascii=False))
' 2>/dev/null
exit 0
