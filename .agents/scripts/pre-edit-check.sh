#!/usr/bin/env bash
# ==============================================================================
# Comprobación previa a editar archivos (paridad Claude Code / Antigravity)
# ==============================================================================
# Uso: pre-edit-check.sh <ruta> [ruta...]      (también: task.sh check <ruta> [ruta...])
# Las rutas relativas se toman del directorio actual (como en el editor), no de la raíz.
#
# Ejecuta, para cada ruta, los mismos controles que los hooks de Claude Code:
#   1. "Cero Código sin Tarea" (require-active-task.sh, AGENTS.md §2.4): sin una tarea
#      IN_PROGRESS no se edita código (Markdown, docs/, specs/, .agents/ y .claude/ libres).
#   2. "El Cerebro va al Agente" (brain-context.sh, AGENTS.md §7.4): muestra las lecciones
#      activas cuyo ámbito cubre la ruta.
# En Claude Code los hooks lo hacen solos; en Antigravity (sin hooks) el agente ejecuta este
# comando antes de editar. Reutiliza los dos scripts, así que la lógica es una sola.
#
# Salida: 0 = se pueden editar todas las rutas; 2 = alguna está bloqueada (motivo en stderr);
#         1 = uso incorrecto.
# Las lecciones se muestran siempre (sin el "una vez por sesión" del hook).
#
# Nota sobre flags de shell:
# No usa 'set -e': el código de salida 2 de require-active-task.sh es un resultado esperado
# que se recoge y se agrega, no un error del script.
# ==============================================================================

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Proyecto = el que contiene este script (no CLAUDE_PROJECT_DIR, que puede apuntar a otro)
ROOT="$(cd "$HERE/../.." && pwd)"

if [ $# -eq 0 ]; then
  printf 'Uso: %s <ruta> [ruta...]\n' "$(basename "$0")" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  # Mismas excepciones que el hook: escape explícito o proyecto sin GLOBAL_STATE.md
  if [ "${MAESTRO_ALLOW_UNTRACKED:-0}" = "1" ] || [ ! -f "$ROOT/GLOBAL_STATE.md" ]; then
    printf '✅ Se puede editar (sin python3 no se pueden mostrar las lecciones).\n'
    exit 0
  fi
  printf 'Bloqueado por AGENTS.md §2.4: se requiere python3 para comprobar la tarea activa y el cerebro.\n' >&2
  exit 2
fi

# JSON del hook con la ruta ABSOLUTA: las relativas se resuelven contra el directorio actual,
# como hace Claude Code (que siempre envía rutas absolutas). Los hooks resuelven una ruta
# relativa contra la raíz del proyecto, así que pasarla tal cual desde un subdirectorio
# comprobaría otro archivo.
hook_json() {
  python3 -c 'import json, os, sys
p = sys.argv[1]
if p and "\n" not in p and "\r" not in p and not os.path.isabs(p):
    p = os.path.join(os.getcwd(), p)
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": p}}))' "$1"
}

RC=0
for path in "$@"; do
  JSON=$(hook_json "$path" 2>/dev/null)
  printf '── %s\n' "$path"
  if [ -z "$JSON" ]; then
    # p. ej. el directorio actual se borró (os.getcwd() falla): sin JSON el hook recibiría una
    # entrada vacía y dejaría pasar la edición, así que se bloquea (TD-006)
    printf '   ⛔ No se pudo resolver la ruta (¿existe el directorio actual?). Ejecuta el comando desde un directorio válido.\n' >&2
    RC=2
    continue
  fi

  if MSG=$(printf '%s' "$JSON" | CLAUDE_PROJECT_DIR="$ROOT" bash "$HERE/require-active-task.sh" 2>&1); then
    printf '   ✅ Se puede editar.\n'
  else
    printf '   ⛔ %s\n' "$(printf '%s' "$MSG" | sed '2,$s/^/      /')" >&2
    RC=2
  fi

  # Sin session_id el hook no deduplica: muestra todas las lecciones del ámbito
  RAW=$(printf '%s' "$JSON" | CLAUDE_PROJECT_DIR="$ROOT" MAESTRO_BRAIN_CONTEXT=1 bash "$HERE/brain-context.sh" 2>/dev/null)
  CTX=$(printf '%s' "$RAW" | python3 -c 'import json, sys
try:
    print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
except Exception:
    pass' 2>/dev/null)
  if [ -n "$CTX" ]; then
    printf '%s\n' "$CTX" | sed 's/^/   /'
  elif [ -n "$RAW" ]; then
    # El hook respondió algo que no es el JSON esperado: no se afirma que no haya lecciones
    printf '   ⚠️  No se pudo leer la respuesta del cerebro; consulta: ./.agents/scripts/task.sh brain for TASK-XXX %s\n' "$path"
  else
    printf '   🧠 Sin lecciones específicas para esta ruta.\n'
  fi
done
exit $RC
