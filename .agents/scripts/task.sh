#!/usr/bin/env bash
# ==============================================================================
# CLI de Gestión de Tareas Multi-Agente (task.sh)
# ==============================================================================
# Manipula el tablero de GLOBAL_STATE.md, gestiona ramas Git por tarea, genera
# traspasos y registra memoria en BRAIN.md. Todas las operaciones leen y
# escriben por columna de la tabla, nunca por coincidencia de texto en la fila.
#
# Columnas del tablero: | ID Tarea | Descripción | Asignado a | Estado | Iteración QA | Criterios |
# ==============================================================================

set -e

# Nota sobre flags de shell:
# Se utiliza 'set -e' para abortar inmediatamente ante comandos fallidos imprevistos.
# No se activan '-u' ni '-o pipefail' deliberadamente para permitir la evaluación
# natural de argumentos posicionales opcionales ($2, $3...) y tuberías de inspección
# donde comandos como grep o diff devuelven código 1 en ausencia de coincidencias.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -f "GLOBAL_STATE.md" ]; then
  PROJECT_ROOT="$(pwd)"
else
  PROJECT_ROOT="$PARENT_ROOT"
fi

STATE_FILE="$PROJECT_ROOT/GLOBAL_STATE.md"
BRAIN_FILE="$PROJECT_ROOT/BRAIN.md"
LL_FILE="$PROJECT_ROOT/.agents/brain/lessons_learned.md"
DEBT_FILE="$PROJECT_ROOT/.agents/brain/tech_debt.md"
HANDOFF_DIR="$PROJECT_ROOT/.agents/handoffs"
ARCHIVE_DIR="$PROJECT_ROOT/.agents/archive"

VALID_STATUSES="BACKLOG|TODO|IN_PROGRESS|IN_REVIEW_QA|AWAITING_HUMAN_APPROVAL|BLOCKED|DONE"
MAX_ITERATIONS=3

# Encabezados que identifican cada tabla (las filas nuevas se añaden al final de la tabla)
HDR_TASKS='^\|[ \t]*ID Tarea[ \t]*\|'
HDR_HISTORY='^\|[ \t]*Fecha[ \t]*\|[ \t]*Agente Emisor'
HDR_LESSONS='^\|[ \t]*ID[ \t]*\|[ \t]*Fecha[ \t]*\|[ \t]*Categor'
HDR_DEBT='^\|[ \t]*ID[ \t]*\|[ \t]*Tarea Vinculada'

COMMAND="${1:-help}"
TODAY=$(date +"%Y-%m-%d")

# Colores ANSI (desactivados si la salida no es una terminal, con NO_COLOR o con TERM=dumb)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  GREEN=$'\033[0;32m'; BLUE=$'\033[0;34m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'
  CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
  GREEN=""; BLUE=""; YELLOW=""; RED=""; CYAN=""; BOLD=""; NC=""
fi

# ------------------------------------------------------------------------------
# Utilidades
# ------------------------------------------------------------------------------

# Los mensajes se imprimen literalmente (%s): el texto del usuario nunca se interpreta como
# secuencias de escape. Los colores llevan el carácter ESC real.
say()  { printf '%s\n' "$*"; }
# die escribe en stderr: solo lleva color si stderr también es una terminal (no ensucia logs)
die()  {
  if [ -n "$RED" ] && [ -t 2 ]; then printf '%s\n' "${RED}❌ Error: $*${NC}" >&2
  else printf '%s\n' "❌ Error: $*" >&2; fi
  exit 1
}

# Sustituye FILE por el contenido de TMP conservando permisos e inodo del original
# (mv dejaría el archivo con los permisos 0600 de mktemp)
replace_file() {
  local tmp="$1" file="$2"
  cat "$tmp" > "$file" && rm -f "$tmp"
}

# Biblioteca del cerebro: norm_text, lecciones (fuente única), relevancia y búsqueda
# shellcheck source=brain-lib.sh
BRAIN_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/brain-lib.sh"
[ -f "$BRAIN_LIB" ] || die "Falta $BRAIN_LIB (instalación incompleta). Restáurala con: init-project.sh --update <proyecto>"
. "$BRAIN_LIB"

LOCK_DIR="$PROJECT_ROOT/.agents/.task_lock"
LOCK_ACQUIRED=0
LOCK_OWNER_PID=0

release_lock() {
  if [ "$LOCK_ACQUIRED" -eq 1 ] && [ "${BASHPID:-$$}" -eq "$LOCK_OWNER_PID" ]; then
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    LOCK_ACQUIRED=0
  fi
}

acquire_lock() {
  local timeout=600 # 600 * 0.05s = 30s (margen seguro para entornos CI bajo carga)
  local waited=0
  local my_pid="${BASHPID:-$$}"
  mkdir -p "$PROJECT_ROOT/.agents" 2>/dev/null || true
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    if [ -f "$LOCK_DIR/pid" ]; then
      local lock_pid
      lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
      if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
        rm -rf "$LOCK_DIR" 2>/dev/null || true
        continue
      fi
    fi
    waited=$((waited + 1))
    if [ "$waited" -ge "$timeout" ]; then
      die "Tiempo de espera agotado al intentar adquirir el bloqueo de concurrencia ($LOCK_DIR)."
    fi
    sleep 0.05 2>/dev/null || sleep 1
  done
  printf "%s" "$my_pid" > "$LOCK_DIR/pid" 2>/dev/null || true
  LOCK_ACQUIRED=1
  LOCK_OWNER_PID="$my_pid"
  # Una señal debe terminar el script tras liberar el lock: un trap de INT/TERM que solo
  # limpia deja que bash continúe y escriba en GLOBAL_STATE.md sin el bloqueo
  trap 'release_lock' EXIT
  trap 'release_lock; exit 130' INT
  trap 'release_lock; exit 143' TERM
}

require_file() {
  [ -f "$1" ] || die "No existe $1."$'\n'"   $2"
}

require_state() {
  require_file "$STATE_FILE" "Créalo con /iniciar-proyecto o con .agents/scripts/init-project.sh."
}

# Texto seguro para una celda de tabla Markdown: sin barras verticales ni saltos de línea
cell() {
  printf '%s' "$1" | tr '\n\r\t|' '   /'
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  printf '%s' "$s"
}

normalize_id() {
  local id
  id=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
  [[ "$id" =~ ^TASK-[0-9]+$ ]] || die "ID de tarea inválido: '$1' (formato esperado: TASK-001)."
  printf '%s' "$id"
}

# Siguiente ID con prefijo (TASK, LL, TD) inspeccionando solo la columna ID de tablas Markdown
next_id() {
  local prefix="$1"; shift
  local files=() f max=0
  for f in "$@"; do
    if [ -f "$f" ]; then files+=("$f"); fi
  done
  if [ "${#files[@]}" -gt 0 ]; then
    max=$(P="$prefix" awk -F'|' '
      /^\|/ {
        c = $2; gsub(/[ \t`]/, "", c)
        if (c ~ ("^" ENVIRON["P"] "-[0-9]+$")) {
          n = substr(c, length(ENVIRON["P"]) + 2) + 0
          if (n > m) m = n
        }
      }
      END { print m + 0 }
    ' "${files[@]}" 2>/dev/null)
  fi
  printf "%s-%03d" "$prefix" $((10#${max:-0} + 1))
}

# Imprime filas | TASK-NNN | ... | de los archivos indicados
table_task_rows() {
  [ "$#" -gt 0 ] || return 0
  awk -F'|' '
    /^\|/ {
      id = $2; gsub(/[ \t`]/, "", id)
      if (id ~ /^TASK-[0-9]+$/) print
    }
  ' "$@"
}

# Imprime las filas del tablero de tareas activas (columna 1 = TASK-NNN)
board_rows() {
  table_task_rows "$STATE_FILE"
}

# Imprime las filas de tareas archivadas en .agents/archive/*.md
archived_rows() {
  local files=() af
  if [ -d "$ARCHIVE_DIR" ]; then
    for af in "$ARCHIVE_DIR"/*.md; do
      if [ -f "$af" ]; then files+=("$af"); fi
    done
  fi
  if [ "${#files[@]}" -gt 0 ]; then
    table_task_rows "${files[@]}"
  fi
}

# Valor limpio de la columna N (2=ID, 3=desc, 4=agente, 5=estado, 6=iteración) para una tarea
task_field() {
  local id="$1" col="$2"
  awk -F'|' -v id="$id" -v col="$col" '
    /^\|/ {
      cur = $2; gsub(/[ \t`]/, "", cur)
      if (cur == id) {
        v = $col; gsub(/`/, "", v); gsub(/^[ \t]+|[ \t]+$/, "", v)
        print v; exit
      }
    }
  ' "$STATE_FILE"
}

require_task() {
  if [ -n "$(task_field "$1" 2)" ]; then
    return 0
  fi
  local arch
  arch=$(archived_rows | awk -F'|' -v id="$1" '{ c=$2; gsub(/[ \t`]/,"",c); if (c==id) { print id; exit } }' || true)
  if [ -n "$arch" ]; then
    die "$1 ya fue completada y archivada en $ARCHIVE_DIR."
  fi
  die "La tarea $1 no existe en el tablero de $STATE_FILE."
}

# Iteraciones de QA consumidas (número antes de /3)
task_iteration() {
  local it
  it=$(task_field "$1" 6 | cut -d/ -f1)
  [[ "$it" =~ ^[0-9]+$ ]] || it=0
  printf '%s' "$it"
}

# Actualiza la fecha de "Última Actualización" en GLOBAL_STATE.md si existe la línea
touch_state_date() {
  [ -f "$STATE_FILE" ] || return 0
  local tmp
  tmp=$(mktemp)
  TODAY="$TODAY" awk '
    /^\- \*\*Última Actualización\*\*:/ { print "- **Última Actualización**: `" ENVIRON["TODAY"] "`"; next }
    { print }
  ' "$STATE_FILE" > "$tmp"
  replace_file "$tmp" "$STATE_FILE"
}

# Reescribe estado (y opcionalmente iteración) solo en la fila de la tarea
set_task() {
  local id="$1" status="$2" iteration="${3:-}"
  local tmp
  tmp=$(mktemp)
  awk -F'|' -v OFS='|' -v id="$id" -v st="$status" -v it="$iteration" '
    /^\|/ {
      cur = $2; gsub(/[ \t`]/, "", cur)
      if (cur == id) {
        $5 = " `" st "` "
        if (it != "") $6 = " `" it "` "
      }
    }
    { print }
  ' "$STATE_FILE" > "$tmp"
  replace_file "$tmp" "$STATE_FILE"
  touch_state_date
}

# Añade ROW al final de la tabla cuyo encabezado coincide con HDR (regex awk)
append_to_table() {
  local file="$1" hdr="$2" row="$3"
  local tmp
  tmp=$(mktemp)
  if ! HDR="$hdr" ROW="$row" awk '
      { lines[NR] = $0 }
      !found && $0 ~ ENVIRON["HDR"] { found = 1; intable = 1; at = NR; next }
      intable { if ($0 ~ /^\|/) at = NR; else intable = 0 }
      END {
        if (!found) exit 2
        for (i = 1; i <= NR; i++) { print lines[i]; if (i == at) print ENVIRON["ROW"] }
      }
    ' "$file" > "$tmp"; then
    rm -f "$tmp"
    die "No se encontró la tabla esperada en $file."
  fi
  replace_file "$tmp" "$file"
}

log_history() {
  local from="$1" to="$2" id="$3" summary="$4"
  append_to_table "$STATE_FILE" "$HDR_HISTORY" \
    "| \`$TODAY\` | $from | $to | \`$id\` | $(cell "$summary") |"
}

in_git() {
  git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# Comandos
# ------------------------------------------------------------------------------

case "$COMMAND" in
  add|start|move|handoff|reject|close|archive|learn|debt|debt-resolve|lesson-retire)
    acquire_lock
    ;;
  check)
    # Comprobación previa a editar (Antigravity y uso manual): delega en pre-edit-check.sh,
    # que reutiliza los hooks de Claude Code. Solo lee, así que no toma el lock.
    shift
    exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pre-edit-check.sh" "$@"
    ;;
  brain)
    # Solo los subcomandos que escriben toman el lock; search, for, doctor y stats son de lectura
    # (doctor lo ejecuta validate-state.sh desde el pre-commit)
    case "${2:-}" in sync|scope) acquire_lock ;; esac
    ;;
esac

case "$COMMAND" in
  list)
    require_state
    say "${BLUE}${BOLD}=== Tablero de Tareas ($STATE_FILE) ===${NC}"
    ROWS=$(board_rows)
    if [ -n "$ROWS" ]; then printf '%s\n' "$ROWS"; else say "No hay tareas registradas."; fi
    ;;

  add)
    require_state
    DESC="$2"
    AGENT="${3:-orchestrator-agent}"
    CRITERIA="${4:-}"
    if [ -z "$DESC" ] || [ -z "$CRITERIA" ]; then
      die "Faltan parámetros."$'\n'"   Uso: ./task.sh add \"<descripción>\" \"<agente>\" \"<criterios de aceptación>\""
    fi
    if [ ! -d "$PROJECT_ROOT/.agents/skills/$AGENT" ]; then
      say "${YELLOW}⚠️  '$AGENT' no coincide con ninguna skill de .agents/skills/ (se registra igualmente).${NC}"
    fi

    ADD_FILES=("$STATE_FILE")
    if [ -d "$ARCHIVE_DIR" ]; then
      for af in "$ARCHIVE_DIR"/*.md; do
        if [ -f "$af" ]; then ADD_FILES+=("$af"); fi
      done
    fi
    NEXT_ID=$(next_id TASK "${ADD_FILES[@]}")
    append_to_table "$STATE_FILE" "$HDR_TASKS" \
      "| \`$NEXT_ID\` | $(cell "$DESC") | $(cell "$AGENT") | \`TODO\` | \`0/$MAX_ITERATIONS\` | $(cell "$CRITERIA") |"
    touch_state_date
    say "${GREEN}✅ Tarea agregada:${NC} $NEXT_ID -> $DESC ($AGENT)"
    ;;

  start)
    require_state
    [ -n "$2" ] || die "Uso: ./task.sh start TASK-001"
    TASK_ID=$(normalize_id "$2")
    require_task "$TASK_ID"
    STATUS=$(task_field "$TASK_ID" 5)
    case "$STATUS" in
      BACKLOG|TODO|IN_PROGRESS) ;;
      AWAITING_HUMAN_APPROVAL) die "$TASK_ID está esperando aprobación humana (AWAITING_HUMAN_APPROVAL). Usa 'task.sh approve $TASK_ID' para aprobarla antes de iniciar." ;;
      IN_REVIEW_QA) die "$TASK_ID está en revisión de QA; espera el veredicto (/qa-review)." ;;
      BLOCKED) die "$TASK_ID está BLOCKED (3/3). Requiere decisión humana; el Orchestrator la reabre con 'task.sh move'." ;;
      DONE) die "$TASK_ID ya está DONE. Crea una tarea nueva si hay más trabajo." ;;
      *) die "Estado desconocido '$STATUS' en $TASK_ID." ;;
    esac

    set_task "$TASK_ID" "IN_PROGRESS"
    say "${GREEN}🚀 Tarea iniciada:${NC} $TASK_ID está ahora en ${BOLD}IN_PROGRESS${NC}"

    if in_git; then
      DESC=$(task_field "$TASK_ID" 3)
      # Prefijo según AGENTS.md §5: "Bug:"/"Fix:"/"Hotfix:" → fix/, "Refactor:" → refactor/, resto → feature/
      PREFIX="feature"
      case "$(printf '%s' "$DESC" | tr '[:upper:]' '[:lower:]')" in
        bug[:\ ]*|fix[:\ ]*|hotfix[:\ ]*) PREFIX="fix";      DESC="${DESC#*[: ]}" ;;
        refactor[:\ ]*)                   PREFIX="refactor"; DESC="${DESC#*[: ]}" ;;
      esac
      SLUG=$(printf '%s\n' "$DESC" | norm_text \
        | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c 1-30 | sed 's/-$//')
      BRANCH="$PREFIX/$TASK_ID-${SLUG:-tarea}"
      if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
        git -C "$PROJECT_ROOT" checkout "$BRANCH" >/dev/null 2>&1 \
          || say "${YELLOW}⚠️  No se pudo cambiar a $BRANCH (¿cambios sin guardar?). Cámbiala manualmente.${NC}"
      else
        CUR_BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || true)
        if [ -n "$CUR_BRANCH" ] && [ "$CUR_BRANCH" != "main" ] && [ "$CUR_BRANCH" != "master" ]; then
          say "${YELLOW}⚠️  Creando rama desde '$CUR_BRANCH' en lugar de main/master.${NC}"
        fi
        git -C "$PROJECT_ROOT" checkout -b "$BRANCH" >/dev/null 2>&1 \
          || say "${YELLOW}⚠️  No se pudo crear la rama $BRANCH. Créala manualmente.${NC}"
      fi
      say "   Rama activa: ${CYAN}$(git -C "$PROJECT_ROOT" branch --show-current)${NC}"
    fi

    # Recordatorio del cerebro (AGENTS.md §7.1): lecciones relevantes para esta tarea (mismo
    # criterio que 'task.sh brain for') y, si sobran líneas, las más recientes del resto
    LESSONS=$(active_lessons)
    if [ -n "$LESSONS" ]; then
      REL=$(relevant_lessons "$(agent_category "$(task_field "$TASK_ID" 4)")" "$(task_field "$TASK_ID" 3) $(task_field "$TASK_ID" 7)" "")
      say "🧠 Lecciones activas ($(printf '%s\n' "$LESSONS" | wc -l | tr -d ' ')); revisa las de esta tarea antes de empezar (detalle: task.sh brain for $TASK_ID):"
      REL="$REL" LESSONS="$LESSONS" awk '
        BEGIN {
          nr = split(ENVIRON["REL"], r, "\n"); shown = 0
          for (i = 1; i <= nr; i++) if (r[i] != "") {
            split(r[i], f, "\t"); seen[f[1]] = 1
            rc = (length(f) >= 6) ? f[6] + 0 : 0
            if (rc > 0) {
              printf "  ⚠️  ALERTA CRÍTICA: %s [%s] (🚨 REINCIDENTE x%d) %s  (%s)\n", f[1], f[2], rc, substr(f[3], 1, 80), f[4]
            } else {
              printf "     %s  [%s] %s  (%s)\n", f[1], f[2], substr(f[3], 1, 90), f[4]
            }
            shown++
          }
          nl = split(ENVIRON["LESSONS"], l, "\n"); rest = 5 - shown; if (rest < 0) rest = 0
          others = 0; for (i = 1; i <= nl; i++) { split(l[i], f, "\t"); if (l[i] != "" && !(f[1] in seen)) others++ }
          skip = others - rest; k = 0
          for (i = 1; i <= nl; i++) { split(l[i], f, "\t"); if (l[i] == "" || (f[1] in seen)) continue; k++; if (k > skip) printf "     %s  [%s] %s\n", f[1], f[2], substr(f[3], 1, 90) }
        }
      '
    elif [ -f "$BRAIN_FILE" ]; then
      say "🧠 Revisa BRAIN.md (gotchas y preferencias) antes de empezar."
    fi
    ;;

  move)
    require_state
    [ -n "$2" ] && [ -n "$3" ] || die "Uso: ./task.sh move TASK-001 <TODO|BACKLOG|AWAITING_HUMAN_APPROVAL> (o IN_PROGRESS al desbloquear una tarea BLOCKED o aprobada)"
    TASK_ID=$(normalize_id "$2")
    NEW_STATUS="$3"
    [[ "$NEW_STATUS" =~ ^($VALID_STATUSES)$ ]] || die "Estado inválido '$NEW_STATUS'. Válidos: $VALID_STATUSES"
    require_task "$TASK_ID"
    CURRENT=$(task_field "$TASK_ID" 5)
    # move no sustituye a las transiciones con control (AGENTS.md §3): DONE solo con close
    # tras QA, IN_REVIEW_QA solo con handoff y BLOCKED solo con el tercer reject
    case "$NEW_STATUS" in
      DONE)         die "$TASK_ID no puede pasar a DONE con move: solo QA la cierra con 'task.sh close' tras revisarla." ;;
      IN_REVIEW_QA) die "$TASK_ID no puede pasar a IN_REVIEW_QA con move: entrégala con 'task.sh handoff $TASK_ID'." ;;
      BLOCKED)      die "$TASK_ID no puede pasar a BLOCKED con move: solo el tercer rechazo de QA ('task.sh reject') la bloquea." ;;
      IN_PROGRESS)
        [ "$CURRENT" = "BLOCKED" ] || [ "$CURRENT" = "AWAITING_HUMAN_APPROVAL" ] \
          || die "$TASK_ID no puede pasar de $CURRENT a IN_PROGRESS con move: usa 'task.sh start $TASK_ID' (crea o cambia a su rama)." ;;
    esac
    if [ "$CURRENT" = "BLOCKED" ]; then
      # Salir de BLOCKED implica una decisión humana: se reinicia el contador de QA
      set_task "$TASK_ID" "$NEW_STATUS" "0/$MAX_ITERATIONS"
      log_history "orchestrator-agent" "Equipo" "$TASK_ID" "Desbloqueada tras decisión humana -> $NEW_STATUS"
    elif [ "$NEW_STATUS" = "AWAITING_HUMAN_APPROVAL" ]; then
      set_task "$TASK_ID" "$NEW_STATUS"
      log_history "orchestrator-agent" "humano" "$TASK_ID" "Pausada para aprobación humana"
    elif [ "$CURRENT" = "AWAITING_HUMAN_APPROVAL" ]; then
      set_task "$TASK_ID" "$NEW_STATUS"
      log_history "humano" "orchestrator-agent" "$TASK_ID" "Aprobada por el usuario -> $NEW_STATUS"
    else
      set_task "$TASK_ID" "$NEW_STATUS"
      # Replanificar (incluido reabrir una tarea DONE) también deja rastro en el historial
      if [ "$CURRENT" != "$NEW_STATUS" ]; then
        log_history "orchestrator-agent" "Equipo" "$TASK_ID" "Replanificada $CURRENT -> $NEW_STATUS"
      fi
    fi
    say "${GREEN}✅ Estado actualizado:${NC} $TASK_ID ahora está en $NEW_STATUS"
    ;;

  hold)
    require_state
    [ -n "$2" ] || die "Uso: ./task.sh hold TASK-001 [\"motivo o punto de control\"]"
    TASK_ID=$(normalize_id "$2")
    REASON="${3:-Punto de control pendiente de aprobación humana}"
    require_task "$TASK_ID"
    CURRENT=$(task_field "$TASK_ID" 5)
    [ "$CURRENT" != "DONE" ] && [ "$CURRENT" != "BLOCKED" ] && [ "$CURRENT" != "IN_REVIEW_QA" ] \
      || die "No se puede pausar $TASK_ID en estado $CURRENT para aprobación humana."
    set_task "$TASK_ID" "AWAITING_HUMAN_APPROVAL"
    log_history "orchestrator-agent" "humano" "$TASK_ID" "Pausada para aprobación humana: $REASON"
    say "${YELLOW}⏸️  Tarea en espera de aprobación humana:${NC} $TASK_ID -> AWAITING_HUMAN_APPROVAL"
    say "   Motivo: $REASON"
    say "   Para reanudar tras visto bueno: ./.agents/scripts/task.sh approve $TASK_ID"
    ;;

  approve)
    require_state
    [ -n "$2" ] || die "Uso: ./task.sh approve TASK-001 [--status TODO|IN_PROGRESS] [--comment \"aprobación\"]"
    TASK_ID=$(normalize_id "$2")
    TARGET_STATUS="TODO"
    COMMENT="Aprobado por el usuario"
    shift 2
    while [ $# -gt 0 ]; do
      case "$1" in
        --status)
          [ -n "${2:-}" ] || die "--status requiere TODO o IN_PROGRESS."
          TARGET_STATUS="$2"; shift 2 ;;
        --status=*)
          TARGET_STATUS="${1#--status=}"; shift ;;
        --comment)
          [ -n "${2:-}" ] || die "--comment requiere texto."
          COMMENT="$2"; shift 2 ;;
        --comment=*)
          COMMENT="${1#--comment=}"; shift ;;
        *)
          die "Opción desconocida para approve: '$1'. Uso: ./task.sh approve TASK-001 [--status TODO|IN_PROGRESS] [--comment \"texto\"]" ;;
      esac
    done
    [[ "$TARGET_STATUS" =~ ^(TODO|IN_PROGRESS)$ ]] || die "Estado destino inválido para approve: '$TARGET_STATUS'. Permitidos: TODO, IN_PROGRESS"
    require_task "$TASK_ID"
    CURRENT=$(task_field "$TASK_ID" 5)
    [ "$CURRENT" = "AWAITING_HUMAN_APPROVAL" ] \
      || die "$TASK_ID está en $CURRENT. Solo tareas en AWAITING_HUMAN_APPROVAL pueden aprobarse con 'task.sh approve'."
    set_task "$TASK_ID" "$TARGET_STATUS"
    log_history "humano" "orchestrator-agent" "$TASK_ID" "Aprobada por el usuario -> $TARGET_STATUS: $COMMENT"
    say "${GREEN}✅ Tarea aprobada por el usuario:${NC} $TASK_ID reanudada en $TARGET_STATUS"
    if [ "$TARGET_STATUS" = "IN_PROGRESS" ]; then
      say "   Recuerda sincronizar la rama de trabajo con: ./.agents/scripts/task.sh start $TASK_ID"
    fi
    ;;

  handoff)
    require_state
    [ -n "$2" ] || die "Uso: ./task.sh handoff TASK-001 [agente-destino] [--verify \"<comando>\"]... [--summary \"<resumen>\"]"
    TASK_ID=$(normalize_id "$2")
    require_task "$TASK_ID"
    STATUS=$(task_field "$TASK_ID" 5)
    [ "$STATUS" = "IN_PROGRESS" ] || die "$TASK_ID está en $STATUS; solo se entrega desde IN_PROGRESS (usa 'task.sh start' primero)."

    shift 2
    TARGET_AGENT=""
    SUMMARY_ARG=""
    VERIFY_CMDS=()

    while [ $# -gt 0 ]; do
      case "$1" in
        --verify)
          [ -n "${2:-}" ] || die "--verify requiere un comando de verificación."
          VERIFY_CMDS+=("$2")
          shift 2
          ;;
        --verify=*)
          VERIFY_CMDS+=("${1#--verify=}")
          shift
          ;;
        --summary)
          [ -n "${2:-}" ] || die "--summary requiere un texto de resumen."
          SUMMARY_ARG="$2"
          shift 2
          ;;
        --summary=*)
          SUMMARY_ARG="${1#--summary=}"
          shift
          ;;
        *)
          if [ -z "$TARGET_AGENT" ]; then
            TARGET_AGENT="$1"
          fi
          shift
          ;;
      esac
    done
    TARGET_AGENT="${TARGET_AGENT:-qa-security-agent}"

    SOURCE_AGENT=$(task_field "$TASK_ID" 4)
    DESC=$(task_field "$TASK_ID" 3)
    ITERATION=$(( $(task_iteration "$TASK_ID") + 1 ))
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Archivos entregados: cambios de la rama respecto a main/master + cambios sin commitear (rutas con -z para caracteres no ASCII, comillas o espacios)
    FILES=""
    if in_git; then
      BASE=""
      for b in main master; do
        if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$b"; then BASE="$b"; break; fi
      done
      if [ -n "$BASE" ] && [ "$(git -C "$PROJECT_ROOT" branch --show-current)" != "$BASE" ]; then
        MB=$(git -C "$PROJECT_ROOT" merge-base HEAD "$BASE" 2>/dev/null || true)
        if [ -n "$MB" ]; then
          while IFS= read -r -d '' p; do
            [ -n "$p" ] && FILES="${FILES}${p}"$'\n'
          done < <(git -C "$PROJECT_ROOT" -c core.quotePath=false diff -z --name-only "$MB" HEAD 2>/dev/null)
        fi
      fi
      UNCOMMITTED=""
      while IFS= read -r -d '' entry; do
        st="${entry:0:2}"
        p="${entry:3}"
        case "$st" in R*|C*|?R|?C) IFS= read -r -d '' _old || true ;; esac
        [ -n "$p" ] && UNCOMMITTED="${UNCOMMITTED}${p}"$'\n'
      done < <(git -C "$PROJECT_ROOT" -c core.quotePath=false status --porcelain -z --untracked-files=all 2>/dev/null)
      FILES=$(printf '%s\n%s\n' "$FILES" "$UNCOMMITTED" | grep -v '^$' | grep -v '^\.agents/handoffs/' | sort -u || true)
    fi

    DELIVERABLES=""
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      DELIVERABLES="$DELIVERABLES    { \"type\": \"file\", \"path\": \"$(json_escape "$f")\" },
"
    done <<< "$FILES"
    DELIVERABLES=$(printf '%s' "$DELIVERABLES" | sed '$ s/,$//')

    if [ ${#VERIFY_CMDS[@]} -eq 0 ]; then
      VERIFY_CMDS=("./.agents/scripts/validate-state.sh")
    fi

    VERIFY_JSON=""
    CMDS_FMT=""
    for cmd in "${VERIFY_CMDS[@]}"; do
      VERIFY_JSON="$VERIFY_JSON    \"$(json_escape "$cmd")\",
"
      if [ -n "$CMDS_FMT" ]; then
        CMDS_FMT="$CMDS_FMT, \`$cmd\`"
      else
        CMDS_FMT="\`$cmd\`"
      fi
    done
    VERIFY_JSON=$(printf '%s' "$VERIFY_JSON" | sed '$ s/,$//')

    mkdir -p "$HANDOFF_DIR"
    HANDOFF_FILE="$HANDOFF_DIR/handoff_${TASK_ID}.json"
    cat > "$HANDOFF_FILE" <<EOF
{
  "task_id": "$TASK_ID",
  "summary": "$(json_escape "$DESC")",
  "source_agent": "$(json_escape "$SOURCE_AGENT")",
  "target_agent": "$(json_escape "$TARGET_AGENT")",
  "timestamp": "$TIMESTAMP",
  "iteration": $ITERATION,
  "deliverables": [
$DELIVERABLES
  ],
  "verification_commands": [
$VERIFY_JSON
  ]
}
EOF

    set_task "$TASK_ID" "IN_REVIEW_QA"
    HIST_SUMMARY="${SUMMARY_ARG:-$DESC}"
    if [ -n "$CMDS_FMT" ]; then
      HIST_SUMMARY="$HIST_SUMMARY. Comandos: $CMDS_FMT"
    fi
    log_history "$SOURCE_AGENT" "$TARGET_AGENT" "$TASK_ID" "$HIST_SUMMARY"

    say "${GREEN}📦 Handoff generado:${NC} ${HANDOFF_FILE#$PROJECT_ROOT/}"
    say "   $TASK_ID -> ${BOLD}IN_REVIEW_QA${NC} (iteración $ITERATION/$MAX_ITERATIONS), revisa: ${CYAN}$TARGET_AGENT${NC}"
    if [ "$TARGET_AGENT" = "$SOURCE_AGENT" ]; then
      say "${YELLOW}⚠️  El destino del handoff ($TARGET_AGENT) es el mismo agente asignado a la tarea: el segundo argumento es quien REVISA, no quien entrega. 'task.sh close' exigirá un revisor distinto.${NC}"
    fi
    ;;

  reject)
    require_state
    [ -n "$2" ] && [ -n "$3" ] || die "Uso: ./task.sh reject TASK-001 \"<motivo del rechazo>\""
    TASK_ID=$(normalize_id "$2")
    REASON="$3"
    require_task "$TASK_ID"
    STATUS=$(task_field "$TASK_ID" 5)
    [ "$STATUS" = "IN_REVIEW_QA" ] || die "$TASK_ID está en $STATUS; solo se rechaza una tarea en IN_REVIEW_QA."

    AGENT=$(task_field "$TASK_ID" 4)
    NEXT=$(( $(task_iteration "$TASK_ID") + 1 ))
    # Reincidencia: el motivo repite algo que una lección activa ya cubría
    REC=$(recurrence_for "$REASON")
    REC_REASON="$REASON"
    if [ -n "$REC" ]; then
      REC_ID="${REC%%$'\t'*}"
      REASON="$REASON (reincidencia de $REC_ID)"
    fi
    if [ "$NEXT" -ge "$MAX_ITERATIONS" ]; then
      set_task "$TASK_ID" "BLOCKED" "$MAX_ITERATIONS/$MAX_ITERATIONS"
      log_history "qa-security-agent" "orchestrator-agent" "$TASK_ID" "Rechazo $MAX_ITERATIONS/$MAX_ITERATIONS: $REASON. BLOCKED, escalar al humano"
      say "${RED}🚨 DEADLOCK ($MAX_ITERATIONS/$MAX_ITERATIONS):${NC} $TASK_ID pasa a ${BOLD}BLOCKED${NC}."
      say "${YELLOW}   Se requiere ESCALAMIENTO AL HUMANO (orchestrator-agent).${NC}"
    else
      set_task "$TASK_ID" "IN_PROGRESS" "$NEXT/$MAX_ITERATIONS"
      log_history "qa-security-agent" "$AGENT" "$TASK_ID" "Rechazo $NEXT/$MAX_ITERATIONS: $REASON"
      say "${YELLOW}⚠️  $TASK_ID rechazada ($NEXT/$MAX_ITERATIONS):${NC} $REASON"
      say "   Vuelve a ${BOLD}IN_PROGRESS${NC}; el especialista retoma con 'task.sh start $TASK_ID'."
    fi
    if [ -n "$REC" ]; then
      # El rechazo ya está registrado: un fallo al anotar la reincidencia solo avisa, nunca lo deshace
      if ! record_recurrence "$TASK_ID" "$REC_ID" "$REC_REASON" 2>/dev/null; then
        say "${YELLOW}⚠️  No se pudo anotar la reincidencia en .agents/brain/recurrences.md (¿permisos?); el rechazo sí quedó registrado.${NC}"
      fi
      say "${YELLOW}🧠 Reincidencia:${NC} $REC_ID ya cubría este fallo (${REC#*$'\t'}). La lección no llegó a tiempo: revisa su ámbito con 'task.sh brain scope $REC_ID \"<globs>\"' o mejora su antídoto."
    fi
    ;;

  close)
    require_state
    [ -n "${2:-}" ] || die "Uso: ./task.sh close TASK-001 [--lesson LL-001 | --no-lesson \"<motivo>\"]"
    TASK_ID=$(normalize_id "$2")
    shift 2
    CLOSE_LESSON=""; CLOSE_NO_LESSON=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --lesson)    [ -n "${2:-}" ] || die "--lesson requiere el ID de la lección (LL-001)."; CLOSE_LESSON="$2"; shift 2 ;;
        --lesson=*)  CLOSE_LESSON="${1#--lesson=}"; shift ;;
        --no-lesson) [ -n "${2:-}" ] || die "--no-lesson requiere el motivo por el que no hay nada que aprender."; CLOSE_NO_LESSON="$2"; shift 2 ;;
        --no-lesson=*) CLOSE_NO_LESSON="${1#--no-lesson=}"; shift ;;
        *) die "Opción desconocida para close: '$1'." ;;
      esac
    done
    [ -z "$CLOSE_LESSON" ] || [ -z "$CLOSE_NO_LESSON" ] || die "Usa --lesson o --no-lesson, no ambos."
    require_task "$TASK_ID"
    STATUS=$(task_field "$TASK_ID" 5)
    [ "$STATUS" = "IN_REVIEW_QA" ] || die "$TASK_ID está en $STATUS; solo QA cierra tareas en IN_REVIEW_QA (cero bypasses de QA)."

    REVIEW_FILE="$PROJECT_ROOT/.agents/reviews/qa_$TASK_ID.md"
    [ -f "$REVIEW_FILE" ] || die "Falta el archivo de veredicto .agents/reviews/qa_$TASK_ID.md. Ejecuta /qa-review antes de cerrar la tarea."

    REVIEWER=$(grep -Ei '^[[:space:]]*[-*]?[[:space:]]*\*{0,2}Revisor\*{0,2}:' "$REVIEW_FILE" 2>/dev/null | head -n1 | sed -E 's/.*:[[:space:]]*`?([a-zA-Z0-9_-]+)`?.*/\1/' | tr -d '[:space:]')
    [ -n "$REVIEWER" ] || die "No se encontró el campo 'Revisor' en $REVIEW_FILE."

    ASSIGNED=$(task_field "$TASK_ID" 4)
    [ "$REVIEWER" != "$ASSIGNED" ] || die "El revisor ($REVIEWER) no puede ser el mismo agente asignado a la tarea ($ASSIGNED). Se requiere revisión por un agente independiente (cero auto-aprobación)."

    # Captura obligatoria (AGENTS.md §7.2): una tarea que fue rechazada o que corrige un defecto
    # (rama fix/ o descripción Bug:/Fix:/Hotfix:) no se cierra sin lección o sin justificar su ausencia
    # Los rechazos se cuentan en el historial (§7), no en el contador n/3: 'move' lo reinicia al
    # salir de BLOCKED, y una tarea que llegó a bloquearse es la que más tiene que enseñar
    NEEDS_LESSON=""
    REJECTIONS=$(TID="$TASK_ID" awk -F'|' '
      /^\|/ {
        em = $3; gsub(/[ \t`]/, "", em)
        id = $5; gsub(/[ \t`]/, "", id)
        if (em == "qa-security-agent" && id == ENVIRON["TID"] && $6 ~ /^[ \t]*Rechazo [0-9]+\/[0-9]+/) n++
      }
      END { print n + 0 }' "$STATE_FILE")
    [ "$(task_iteration "$TASK_ID")" -gt "$REJECTIONS" ] && REJECTIONS=$(task_iteration "$TASK_ID")
    [ "$REJECTIONS" -ge 1 ] && NEEDS_LESSON="tuvo $REJECTIONS rechazo(s) de QA"
    if [ -z "$NEEDS_LESSON" ]; then
      case "$(task_field "$TASK_ID" 3 | tr '[:upper:]' '[:lower:]')" in
        bug[:\ ]*|fix[:\ ]*|hotfix[:\ ]*) NEEDS_LESSON="corrige un defecto" ;;
      esac
    fi
    if [ -z "$NEEDS_LESSON" ] && in_git && [ -n "$(git -C "$PROJECT_ROOT" for-each-ref --format='%(refname:short)' "refs/heads/fix/$TASK_ID-*" "refs/heads/fix/$TASK_ID" 2>/dev/null)" ]; then
      NEEDS_LESSON="corrige un defecto (rama fix/)"
    fi
    LESSON_NOTE=""
    if [ -n "$CLOSE_LESSON" ]; then
      CLOSE_LESSON=$(printf '%s' "$CLOSE_LESSON" | tr '[:lower:]' '[:upper:]')
      [[ "$CLOSE_LESSON" =~ ^LL-[0-9]+$ ]] || die "ID de lección inválido: '$CLOSE_LESSON' (formato LL-001)."
      all_lessons | awk -F'\t' -v id="$CLOSE_LESSON" '$1 == id { f = 1 } END { exit !f }' \
        || die "$CLOSE_LESSON no existe en el cerebro. Regístrala antes con 'task.sh learn' (skill /aprender)."
      active_lessons | awk -F'\t' -v id="$CLOSE_LESSON" '$1 == id { f = 1 } END { exit !f }' \
        || die "$CLOSE_LESSON está OBSOLETA: una lección retirada no vale como aprendizaje de esta tarea. Registra una nueva con 'task.sh learn'."
      LESSON_NOTE=" Lección: $CLOSE_LESSON."
    elif [ -n "$CLOSE_NO_LESSON" ]; then
      case "$CLOSE_NO_LESSON" in *[![:space:]]*) ;; *) die "--no-lesson requiere un motivo." ;; esac
      LESSON_NOTE=" Sin lección: $CLOSE_NO_LESSON."
    elif [ -n "$NEEDS_LESSON" ]; then
      die "$TASK_ID $NEEDS_LESSON: antes de cerrarla registra lo aprendido con 'task.sh learn ... --paths \"<globs>\"' y cierra con 'task.sh close $TASK_ID --lesson LL-XXX', o justifica que no hay nada que aprender con 'task.sh close $TASK_ID --no-lesson \"<motivo>\"'."
    fi

    set_task "$TASK_ID" "DONE"
    log_history "$REVIEWER" "orchestrator-agent" "$TASK_ID" "Aprobada por QA -> DONE.$LESSON_NOTE"
    say "${GREEN}✅ $TASK_ID aprobada y cerrada (DONE).${NC}"
    if in_git; then
      BRANCH=$(git -C "$PROJECT_ROOT" for-each-ref --format='%(refname:short)' "refs/heads/*/$TASK_ID-*" "refs/heads/$TASK_ID-*" "refs/heads/*/$TASK_ID" 2>/dev/null | head -n1)
      if [ -n "$BRANCH" ]; then
        say "${CYAN}💡 Comando de fusión y limpieza:${NC}"
        say "   git checkout main && git merge --no-ff $BRANCH && git branch -d $BRANCH"
      fi
    fi
    ;;

  archive)
    require_state
    shift
    KEEP=0
    PHASE_LABEL=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --keep)
          [ -n "${2:-}" ] && [[ "${2:-}" =~ ^[0-9]+$ ]] || die "--keep requiere un entero >= 0 (ej. --keep 5)."
          KEEP="$2"; shift 2 ;;
        --keep=*)
          KEEP="${1#--keep=}"
          [[ "$KEEP" =~ ^[0-9]+$ ]] || die "--keep requiere un entero >= 0 (ej. --keep=5)."
          shift ;;
        --phase)
          [ -n "${2:-}" ] || die "--phase requiere el nombre de la fase archivada."
          PHASE_LABEL="$2"; shift 2 ;;
        --phase=*)
          PHASE_LABEL="${1#--phase=}"; shift ;;
        *)
          die "Opción desconocida para archive: '$1'. Uso: ./task.sh archive [--keep N] [--phase \"<fase>\"]" ;;
      esac
    done

    DONE_ROWS=$(board_rows | awk -F'|' '{ st=$5; gsub(/[ \t`]/,"",st); if (st=="DONE") print }')
    DONE_COUNT=0
    [ -n "$DONE_ROWS" ] && DONE_COUNT=$(printf '%s\n' "$DONE_ROWS" | grep -c '^|' || true)
    if [ "$DONE_COUNT" -le "$KEEP" ]; then
      say "ℹ️  No hay tareas DONE para archivar (en tablero: $DONE_COUNT, --keep $KEEP)."
      exit 0
    fi

    ARCHIVE_COUNT=$((DONE_COUNT - KEEP))
    TO_ARCHIVE_ROWS=$(printf '%s\n' "$DONE_ROWS" | head -n "$ARCHIVE_COUNT")
    ARCHIVE_IDS=$(printf '%s\n' "$TO_ARCHIVE_ROWS" | awk -F'|' '{ id=$2; gsub(/[ \t`]/,"",id); printf "%s ", id }')
    FIRST_ID=$(printf '%s' "$ARCHIVE_IDS" | awk '{ print $1 }')
    LAST_ID=$(printf '%s' "$ARCHIVE_IDS" | awk '{ print $NF }')

    EXISTING_ARCH=$(archived_rows || true)
    if [ -n "$EXISTING_ARCH" ]; then
      DUP_ID=$(printf '%s\n' "$EXISTING_ARCH" | IDS="$ARCHIVE_IDS" awk -F'|' '
        BEGIN { n=split(ENVIRON["IDS"], a, " "); for (i=1;i<=n;i++) if (a[i]!="") want[a[i]]=1 }
        /^\|/ { cur=$2; gsub(/[ \t`]/,"",cur); if (cur in want) { print cur; exit } }
      ')
      [ -z "$DUP_ID" ] || die "$DUP_ID ya existe en $ARCHIVE_DIR; resuelve el duplicado antes de archivar."
    fi

    mkdir -p "$ARCHIVE_DIR"
    ARCHIVE_BASENAME="tasks_${TODAY}.md"
    ARCHIVE_FILE="$ARCHIVE_DIR/$ARCHIVE_BASENAME"
    if [ ! -f "$ARCHIVE_FILE" ]; then
      cat > "$ARCHIVE_FILE" <<EOF_ARCH
# Archivo de Tareas Completadas — $TODAY

> Tareas \`DONE\` archivadas desde \`GLOBAL_STATE.md\`. Contabilizadas por \`task.sh metrics\`, \`task.sh add\` (\`next_id\`) y \`validate-state.sh\`.

| ID Tarea | Descripción | Asignado a | Estado | Iteración QA | Criterios de Aceptación |
| :--- | :--- | :--- | :--- | :---: | :--- |
EOF_ARCH
    fi

    tmp_rows=$(mktemp)
    printf '%s\n' "$TO_ARCHIVE_ROWS" > "$tmp_rows"
    tmp_arch=$(mktemp)
    if ! HDR="$HDR_TASKS" ROWS_FILE="$tmp_rows" awk '
      { lines[NR] = $0 }
      !found && $0 ~ ENVIRON["HDR"] { found = 1; intable = 1; at = NR; next }
      intable { if ($0 ~ /^\|/) at = NR; else intable = 0 }
      END {
        if (!found) exit 2
        for (i = 1; i <= NR; i++) {
          print lines[i]
          if (i == at) {
            while ((getline r < ENVIRON["ROWS_FILE"]) > 0) print r
            close(ENVIRON["ROWS_FILE"])
          }
        }
      }
    ' "$ARCHIVE_FILE" > "$tmp_arch"; then
      rm -f "$tmp_rows" "$tmp_arch"
      die "No se encontró la tabla de tareas en $ARCHIVE_FILE."
    fi
    rm -f "$tmp_rows"
    replace_file "$tmp_arch" "$ARCHIVE_FILE"

    tmp_state=$(mktemp)
    HDR="$HDR_TASKS" IDS="$ARCHIVE_IDS" awk '
      BEGIN {
        n = split(ENVIRON["IDS"], arr, " ")
        for (i = 1; i <= n; i++) if (arr[i] != "") drop[arr[i]] = 1
      }
      !in_tasks && $0 ~ ENVIRON["HDR"] { in_tasks = 1; print; next }
      in_tasks {
        if ($0 !~ /^\|/) { in_tasks = 0; print; next }
        cur = $2; gsub(/[ \t`]/, "", cur)
        if (cur in drop) next
        print; next
      }
      { print }
    ' "$STATE_FILE" > "$tmp_state"
    replace_file "$tmp_state" "$STATE_FILE"
    touch_state_date

    RANGE_LABEL="$FIRST_ID"
    [ "$FIRST_ID" != "$LAST_ID" ] && RANGE_LABEL="${FIRST_ID}..${LAST_ID}"
    PHASE_NOTE=""
    [ -n "$PHASE_LABEL" ] && PHASE_NOTE=" ($(cell "$PHASE_LABEL"))"
    log_history "orchestrator-agent" "orchestrator-agent" "$RANGE_LABEL" "Archivadas $ARCHIVE_COUNT tareas DONE${PHASE_NOTE} en .agents/archive/$ARCHIVE_BASENAME (--keep $KEEP)."

    say "${GREEN}📦 Archivadas $ARCHIVE_COUNT tareas DONE${PHASE_NOTE} en .agents/archive/$ARCHIVE_BASENAME (conservadas en tablero: $KEEP DONE).${NC}"
    ;;

  metrics)
    require_state
    ACTIVE_ROWS=$(board_rows)
    ARCH_ROWS=$(archived_rows)
    ROWS=$(printf '%s\n%s\n' "$ACTIVE_ROWS" "$ARCH_ROWS" | grep -v '^$' || true)
    if [ -n "$ROWS" ]; then
      TOTAL=$(printf '%s\n' "$ROWS" | grep -c '^|' || true)
    else
      TOTAL=0
    fi
    if [ "${TOTAL:-0}" -eq 0 ]; then say "No hay tareas registradas."; exit 0; fi

    count_status() { printf '%s\n' "$ROWS" | awk -F'|' -v s="$1" '{ v=$5; gsub(/[ \t`]/,"",v); if (v==s) n++ } END { print n+0 }'; }
    count_iter()   { printf '%s\n' "$ROWS" | awk -F'|' -v s="$1" '{ v=$6; gsub(/[ \t`]/,"",v); if (v==s) n++ } END { print n+0 }'; }

    DONE=$(count_status DONE); IN_PROG=$(count_status IN_PROGRESS); IN_QA=$(count_status IN_REVIEW_QA)
    TODO=$(count_status TODO); BACKLOG=$(count_status BACKLOG); BLOCKED=$(count_status BLOCKED)
    ACTIVE_DONE=$(printf '%s\n' "$ACTIVE_ROWS" | awk -F'|' '{ v=$5; gsub(/[ \t`]/,"",v); if (v=="DONE") n++ } END { print n+0 }')
    ARCHIVED_DONE=$((DONE - ACTIVE_DONE))
    PCT=$((DONE * 100 / TOTAL)); FILLED=$((PCT * 20 / 100)); BAR=""
    for ((i=0; i<20; i++)); do if [ $i -lt $FILLED ]; then BAR="${BAR}█"; else BAR="${BAR}░"; fi; done

    say "${BLUE}${BOLD}=== Métricas del Proyecto ===${NC}"
    say "Progreso: [${GREEN}${BAR}${NC}] ${BOLD}${PCT}%${NC} ($DONE de $TOTAL tareas)"
    say ""
    if [ "$ARCHIVED_DONE" -gt 0 ]; then
      say "  - ${GREEN}DONE:${NC}         $DONE ($ACTIVE_DONE activas, $ARCHIVED_DONE archivadas)"
    else
      say "  - ${GREEN}DONE:${NC}         $DONE"
    fi
    say "  - ${YELLOW}IN_REVIEW_QA:${NC} $IN_QA"
    say "  - ${CYAN}IN_PROGRESS:${NC}  $IN_PROG"
    say "  - ${BLUE}TODO:${NC}         $TODO"
    say "  - BACKLOG:      $BACKLOG"
    if [ "$BLOCKED" -gt 0 ]; then
      say "  - ${RED}${BOLD}BLOCKED:${NC}      $BLOCKED 🚨 (requiere decisión humana)"
    else
      say "  - BLOCKED:      0"
    fi
    say ""
    say "Rechazos de QA acumulados: 1/3 → $(count_iter 1/3) · 2/3 → $(count_iter 2/3) · 3/3 → $(count_iter 3/3)"
    ;;

  doctor)
    require_state
    say "${BLUE}${BOLD}=== Diagnóstico General del Proyecto (task.sh doctor) ===${NC}"
    say "Directorio: $PROJECT_ROOT"
    say ""
    DOCTOR_FAILED=0

    # 1. Validación de estado global y tablero
    say "${BOLD}[1/5] Estado Global (validate-state.sh)...${NC}"
    VALIDATE_SCRIPT="$SCRIPT_DIR/validate-state.sh"
    [ -f "$VALIDATE_SCRIPT" ] || VALIDATE_SCRIPT="$PROJECT_ROOT/.agents/scripts/validate-state.sh"
    if [ -f "$VALIDATE_SCRIPT" ]; then
      if VAL_OUT=$(bash "$VALIDATE_SCRIPT" "$STATE_FILE" 2>&1); then
        say "  ${GREEN}✅ Estado global íntegro y sin errores${NC}"
      else
        say "  ${RED}❌ Error en validación de estado global:${NC}"
        printf '%s\n' "$VAL_OUT" | sed 's/^/     /'
        DOCTOR_FAILED=1
      fi
    else
      say "  ${YELLOW}⚠️  validate-state.sh no encontrado en $VALIDATE_SCRIPT${NC}"
    fi

    # 2. Salud del cerebro (lecciones, sincronía y deuda)
    say "${BOLD}[2/5] Salud del Cerebro (task.sh brain doctor)...${NC}"
    DOC_RC=0
    DOC_OUT=$(brain_doctor 2>&1) || DOC_RC=1
    if [ "$DOC_RC" -eq 0 ]; then
      say "  ${GREEN}✅ Cerebro sano y sincronizado${NC}$( [ -n "$DOC_OUT" ] && printf ' (con avisos)' )"
      if [ -n "$DOC_OUT" ]; then
        printf '%s\n' "$DOC_OUT" | sed 's/^/     /'
      fi
    else
      say "  ${RED}❌ Errores detectados en el cerebro:${NC}"
      printf '%s\n' "$DOC_OUT" | sed 's/^/     /'
      DOCTOR_FAILED=1
    fi

    # 3. Linter activo de antipatrones históricos
    say "${BOLD}[3/5] Linter de Antipatrones del Cerebro (task.sh brain lint)...${NC}"
    LINT_RC=0
    LINT_OUT=$(brain_lint 2>&1) || LINT_RC=1
    if [ "$LINT_RC" -eq 0 ]; then
      say "  ${GREEN}✅ 0 violaciones de antipatrones aprendidos${NC}"
    else
      say "  ${RED}❌ Violaciones de antipatrones detectadas:${NC}"
      printf '%s\n' "$LINT_OUT" | sed 's/^/     /'
      DOCTOR_FAILED=1
    fi

    # 4. Escaneo de secretos expuestos
    say "${BOLD}[4/5] Escaneo de Secretos (scan-secrets.sh)...${NC}"
    SCAN_SCRIPT="$SCRIPT_DIR/scan-secrets.sh"
    [ -f "$SCAN_SCRIPT" ] || SCAN_SCRIPT="$PROJECT_ROOT/.agents/scripts/scan-secrets.sh"
    if [ -f "$SCAN_SCRIPT" ]; then
      if in_git; then
        if SEC_OUT=$(bash "$SCAN_SCRIPT" --all 2>&1); then
          say "  ${GREEN}✅ Repositorio limpio de secretos y archivos .env expuestos${NC}"
        else
          say "  ${RED}❌ Posibles secretos detectados:${NC}"
          printf '%s\n' "$SEC_OUT" | sed 's/^/     /'
          DOCTOR_FAILED=1
        fi
      else
        say "  ${YELLOW}⚠️  No es un repositorio Git; escaneo de secretos omitido${NC}"
      fi
    else
      say "  ${YELLOW}⚠️  scan-secrets.sh no encontrado en $SCAN_SCRIPT${NC}"
    fi

    # 5. Estructura y calidad de skills
    say "${BOLD}[5/5] Estructura de Skills (test-skills.sh)...${NC}"
    SKILLS_SCRIPT="$PROJECT_ROOT/tests/test-skills.sh"
    [ -f "$SKILLS_SCRIPT" ] || SKILLS_SCRIPT="$PARENT_ROOT/tests/test-skills.sh"
    if [ -f "$SKILLS_SCRIPT" ]; then
      if SKILL_OUT=$(bash "$SKILLS_SCRIPT" 2>&1); then
        SKILL_COUNT=$(printf '%s\n' "$SKILL_OUT" | grep -oE '[0-9]+ skills auditadas' | head -n 1 || true)
        [ -n "$SKILL_COUNT" ] || SKILL_COUNT="Skills verificadas"
        say "  ${GREEN}✅ Estructura y calidad de skills ($SKILL_COUNT)${NC}"
      else
        say "  ${RED}❌ Errores en la validación de skills:${NC}"
        printf '%s\n' "$SKILL_OUT" | sed 's/^/     /'
        DOCTOR_FAILED=1
      fi
    else
      say "  ${CYAN}ℹ️  tests/test-skills.sh no presente en el proyecto (omitido)${NC}"
    fi

    say ""
    say "================================================================="
    if [ "$DOCTOR_FAILED" -eq 0 ]; then
      say "${GREEN}${BOLD}✅ Diagnóstico completado sin errores. El proyecto está listo y sano.${NC}"
      exit 0
    else
      die "El diagnóstico encontró problemas que deben corregirse (ver detalle arriba)."
    fi
    ;;

  diff)
    in_git || die "No se detectó un repositorio Git en $PROJECT_ROOT."
    shift # descartar 'diff'
    STAT_ONLY=0
    TARGET_TASK=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --stat) STAT_ONLY=1; shift ;;
        --stat=*) STAT_ONLY=1; shift ;;
        *) TARGET_TASK="$1"; shift ;;
      esac
    done

    BASE_REF="main"
    git -C "$PROJECT_ROOT" rev-parse --verify main >/dev/null 2>&1 || BASE_REF="master"

    BRANCH=""
    TASK_LABEL=""
    if [ -n "$TARGET_TASK" ]; then
      TASK_ID=$(normalize_id "$TARGET_TASK")
      TASK_LABEL="$TASK_ID"
      BRANCH=$(git -C "$PROJECT_ROOT" for-each-ref --format='%(refname:short)' refs/heads/ | grep -E "^(feature|fix|refactor)/${TASK_ID}(-[^/]+)?$" | head -n 1 || true)
      if [ -z "$BRANCH" ]; then
        CUR=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        if [[ "$CUR" =~ ^(feature|fix|refactor)/${TASK_ID} ]]; then
          BRANCH="$CUR"
        fi
      fi
      if [ -z "$BRANCH" ]; then
        die "No se encontró una rama Git para la tarea '$TASK_ID'."
      fi
    else
      CUR=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
      if [ "$CUR" = "main" ] || [ "$CUR" = "master" ] || [ "$CUR" = "HEAD" ] || [ -z "$CUR" ]; then
        IN_PROG=$(board_rows | awk -F'|' '{ id=$2; st=$5; gsub(/[ \t`]/,"",id); gsub(/[ \t`]/,"",st); if (st=="IN_PROGRESS") { print id; exit } }')
        if [ -n "$IN_PROG" ]; then
          TASK_LABEL="$IN_PROG"
          BRANCH=$(git -C "$PROJECT_ROOT" for-each-ref --format='%(refname:short)' refs/heads/ | grep -E "^(feature|fix|refactor)/${IN_PROG}(-[^/]+)?$" | head -n 1 || true)
        fi
        if [ -z "$BRANCH" ]; then
          die "Uso: ./task.sh diff [TASK-ID] [--stat]. No estás en una rama de tarea ni hay una tarea IN_PROGRESS con rama local."
        fi
      else
        BRANCH="$CUR"
        TASK_LABEL=$(printf '%s' "$BRANCH" | grep -oE 'TASK-[0-9]+' || echo "$BRANCH")
      fi
    fi

    MERGE_BASE=$(git -C "$PROJECT_ROOT" merge-base "$BASE_REF" "$BRANCH" 2>/dev/null || true)
    [ -n "$MERGE_BASE" ] || die "No se pudo determinar el punto de divergencia (merge-base) entre '$BASE_REF' y '$BRANCH'."

    CUR_BRANCH=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    DIFF_TARGET="$MERGE_BASE..$BRANCH"
    if [ "$CUR_BRANCH" = "$BRANCH" ]; then
      DIFF_TARGET="$MERGE_BASE"
    fi

    # Comprobar si hay cambios
    if git -C "$PROJECT_ROOT" diff --quiet "$DIFF_TARGET"; then
      say "No hay cambios en '$BRANCH' respecto a '$BASE_REF' ($MERGE_BASE)."
      exit 0
    fi

    say "${BLUE}${BOLD}=== Diff de $TASK_LABEL ($BRANCH vs $BASE_REF) ===${NC}"
    git -C "$PROJECT_ROOT" -c core.quotePath=false diff --stat "$DIFF_TARGET"
    if [ "$STAT_ONLY" -eq 0 ]; then
      say ""
      git -C "$PROJECT_ROOT" -c core.quotePath=false diff "$DIFF_TARGET"
    fi
    ;;

  dashboard)
    require_state
    OUT_FILE="$PROJECT_ROOT/docs/dashboard.html"
    shift
    while [ $# -gt 0 ]; do
      case "$1" in
        -o|--output)
          [ -n "${2:-}" ] || die "--output requiere la ruta del archivo HTML."
          OUT_FILE="$2"; shift 2 ;;
        --output=*)
          OUT_FILE="${1#--output=}"; shift ;;
        *)
          die "Opción desconocida para dashboard: '$1'. Uso: ./task.sh dashboard [--output ruta/a/dashboard.html]" ;;
      esac
    done
    mkdir -p "$(dirname "$OUT_FILE")"
    python3 "$PROJECT_ROOT/.agents/scripts/generate-dashboard.py" "$STATE_FILE" "$BRAIN_FILE" "$PROJECT_ROOT/.agents/brain/lessons_learned.md" "$DEBT_FILE" "$OUT_FILE" || die "Error generando el dashboard."
    say "${GREEN}📊 Dashboard interactivo generado en:${NC} $OUT_FILE"
    say "   Para abrir en navegador: file://$OUT_FILE"
    ;;

  serve)
    require_state
    shift
    exec python3 "$PROJECT_ROOT/.agents/scripts/dashboard-server.py" "$@"
    ;;

  commit)
    [ -n "$2" ] && [ -n "$3" ] || die "Uso: ./task.sh commit TASK-001 \"descripción\" [feat|fix|test|refactor|docs|perf|chore|style|build|ci] [--trailer \"Clave: valor\"]..."
    TASK_ID=$(normalize_id "$2")
    MSG="$3"
    shift 3
    TYPE="feat"
    TRAILERS=()
    # Trailers de autoría (ej. Co-Authored-By): --trailer "<línea>" repetible, o MAESTRO_COMMIT_TRAILER
    [ -n "${MAESTRO_COMMIT_TRAILER:-}" ] && TRAILERS+=("$MAESTRO_COMMIT_TRAILER")
    while [ $# -gt 0 ]; do
      case "$1" in
        --trailer)
          [ -n "${2:-}" ] || die "--trailer requiere una línea (ej. \"Co-Authored-By: Nombre <correo>\")."
          TRAILERS+=("$2"); shift 2 ;;
        --trailer=*) TRAILERS+=("${1#--trailer=}"); shift ;;
        *) TYPE="$1"; shift ;;
      esac
    done
    for t in ${TRAILERS[@]+"${TRAILERS[@]}"}; do
      case "$t" in *$'\n'*|*$'\r'*) die "Trailer inválido: debe ser una sola línea (formato 'Clave: valor')." ;; esac
      [[ "$t" =~ ^[A-Za-z][A-Za-z0-9-]*:\ .+ ]] || die "Trailer inválido: '$t' (formato 'Clave: valor')."
    done
    [[ "$TYPE" =~ ^(feat|fix|test|docs|refactor|perf|chore|style|build|ci)$ ]] || die "Tipo de commit inválido: '$TYPE'."
    in_git || die "No se detectó un repositorio Git en $PROJECT_ROOT."
    if [ -f "$STATE_FILE" ] && [ -z "$(task_field "$TASK_ID" 2)" ]; then
      say "${YELLOW}⚠️  $TASK_ID no está en el tablero; se hace el commit igualmente.${NC}"
    fi

    # Si no hay nada preparado, solo se añaden archivos ya versionados (nunca archivos nuevos a ciegas)
    if git -C "$PROJECT_ROOT" diff --cached --quiet; then
      git -C "$PROJECT_ROOT" add -u
    fi
    UNTRACKED=$(git -C "$PROJECT_ROOT" ls-files --others --exclude-standard)
    if [ -n "$UNTRACKED" ]; then
      say "${YELLOW}⚠️  Archivos nuevos NO incluidos (añádelos con 'git add <archivo>' si corresponden):${NC}"
      printf '%s\n' "$UNTRACKED" | sed 's/^/     /'
    fi
    git -C "$PROJECT_ROOT" diff --cached --quiet && die "No hay cambios preparados para el commit."

    FULL_MSG="${TYPE}(${TASK_ID}): ${MSG}"
    say "${CYAN}-> Commit:${NC} $FULL_MSG"
    if [ ${#TRAILERS[@]} -gt 0 ]; then
      TRAILER_BLOCK=$(printf '%s\n' "${TRAILERS[@]}")
      git -C "$PROJECT_ROOT" commit -m "$FULL_MSG" -m "$TRAILER_BLOCK"
    else
      git -C "$PROJECT_ROOT" commit -m "$FULL_MSG"
    fi
    ;;

  learn)
    shift
    FORCE=0
    SCOPE='*'
    LEARN_ARGS=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --force) FORCE=1; shift ;;
        --paths)
          [ -n "${2:-}" ] || die "--paths requiere globs separados por comas (ej. \"src/api/*.ts,server/*\")."
          SCOPE="$2"; shift 2 ;;
        --paths=*) SCOPE="${1#--paths=}"; shift ;;
        *) LEARN_ARGS+=("$1"); shift ;;
      esac
    done
    DESC="${LEARN_ARGS[0]:-}"
    CAT="${LEARN_ARGS[1]:-general}"
    CAUSE="${LEARN_ARGS[2]:-Por documentar}"
    FIX="${LEARN_ARGS[3]:-Por documentar}"
    [ -n "$DESC" ] || die "Uso: ./task.sh learn \"<problema>\" [categoría] [\"<causa raíz>\"] [\"<solución>\"] [--paths \"<globs>\"] [--force]"
    require_file "$BRAIN_FILE" "Créalo desde .agents/templates/BRAIN_TEMPLATE.md."
    ensure_lessons_file
    ensure_lessons_schema
    adopt_brain_lessons
    CAT_UPPER=$(printf '%s' "$CAT" | tr '[:lower:]' '[:upper:]')
    case "$SCOPE" in *$'\n'*|*$'\r'*|*'|'*) die "Ámbito inválido: usa globs separados por comas, sin '|' ni saltos de línea." ;; esac
    SCOPE=$(norm_scope "$SCOPE")
    [ -n "$SCOPE" ] || die "Ámbito vacío: indica al menos un glob en --paths, o no uses --paths para una lección general."

    # Control de duplicados: lección ACTIVA equivalente o con la mayoría de palabras en común
    if [ "$FORCE" -eq 0 ]; then
      SIMILAR=$(similar_lesson "$DESC")
      if [ -n "$SIMILAR" ]; then
        die "Ya existe una lección parecida: $SIMILAR. Actualiza su antídoto en lessons_learned.md, retírala con 'task.sh lesson-retire' o repite el comando con --force."
      fi
    fi

    # Fuente única: la fila se escribe en lessons_learned.md y BRAIN.md se regenera
    NEXT_ID=$(next_id LL "$BRAIN_FILE" "$LL_FILE")
    append_to_table "$LL_FILE" "$HDR_LESSONS" \
      "| \`$NEXT_ID\` | $TODAY | \`[$(cell "$CAT_UPPER")]\` | $(cell "$DESC") | $(cell "$CAUSE") | $(cell "$FIX") | \`$SCOPE\` | \`ACTIVO\` |"
    brain_sync
    say "${GREEN}🧠 Lección registrada:${NC} $NEXT_ID -> [$CAT_UPPER] $DESC (ámbito: $SCOPE)"
    ;;

  debt)
    DESC="$2"
    TASK_ID="${3:-}"
    ACTION="${4:-Refactorización pendiente}"
    PRIORITY=$(printf '%s' "${5:-MEDIA}" | tr '[:lower:]' '[:upper:]')
    [ -n "$DESC" ] && [ -n "$TASK_ID" ] || die "Uso: ./task.sh debt \"<descripción>\" TASK-001 \"<acción definitiva>\" [ALTA|MEDIA|BAJA]"
    TASK_ID=$(normalize_id "$TASK_ID")
    [[ "$PRIORITY" =~ ^(ALTA|MEDIA|BAJA)$ ]] || die "Prioridad inválida '$PRIORITY' (ALTA|MEDIA|BAJA)."
    require_file "$DEBT_FILE" "Créalo desde .agents/templates/tech_debt_template.md."

    NEXT_ID=$(next_id TD "$DEBT_FILE")
    append_to_table "$DEBT_FILE" "$HDR_DEBT" \
      "| \`$NEXT_ID\` | \`$TASK_ID\` | $TODAY | General | $(cell "$DESC") | Workaround temporal | $(cell "$ACTION") | \`$PRIORITY\` |"
    debt_sync
    say "${YELLOW}📋 Deuda técnica registrada:${NC} $NEXT_ID -> $DESC (vinculada a $TASK_ID)"
    ;;

  debt-resolve)
    [ -n "${2:-}" ] || die "Uso: ./task.sh debt-resolve TD-001"
    TD_ID=$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')
    [[ "$TD_ID" =~ ^TD-[0-9]+$ ]] || die "ID de deuda inválido: '$2' (formato TD-001)."
    require_file "$DEBT_FILE" "Créalo desde .agents/templates/tech_debt_template.md."
    grep -qE "^\|[[:space:]]*\`?$TD_ID\`?[[:space:]]*\|" "$DEBT_FILE" || die "$TD_ID no existe en $DEBT_FILE."
    # tech_debt.md conserva la fila marcada SALDADA (así el ID no se reutiliza y queda la traza);
    # del resumen de BRAIN.md se retira al sincronizar §6
    if awk -F'|' -v id="$TD_ID" '/^\|/ { c = $2; gsub(/[ \t`]/, "", c); if (c == id) { p = $(NF-1); gsub(/[ \t`]/, "", p); if (p == "SALDADA") f = 1 } } END { exit !f }' "$DEBT_FILE"; then
      die "$TD_ID ya estaba marcada como SALDADA."
    fi
    awk -F'|' -v OFS='|' -v id="$TD_ID" '
      /^\|/ { c = $2; gsub(/[ \t`]/, "", c); if (c == id) { $(NF-1) = " `SALDADA` " } }
      { print }
    ' "$DEBT_FILE" > "$DEBT_FILE.tmp" && replace_file "$DEBT_FILE.tmp" "$DEBT_FILE"
    debt_sync
    say "${GREEN}✅ Deuda técnica saldada:${NC} $TD_ID marcada SALDADA en tech_debt.md y retirada de BRAIN.md."
    ;;

  lesson-retire)
    [ -n "${2:-}" ] || die "Uso: ./task.sh lesson-retire LL-001"
    LL_ID=$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')
    [[ "$LL_ID" =~ ^LL-[0-9]+$ ]] || die "ID de lección inválido: '$2' (formato LL-001)."
    ensure_lessons_file
    ensure_lessons_schema
    adopt_brain_lessons
    grep -qE "^\|[[:space:]]*\`?$LL_ID\`?[[:space:]]*\|" "$LL_FILE" || die "$LL_ID no existe en $LL_FILE."
    awk -F'|' -v OFS='|' -v id="$LL_ID" '
      /^\|/ { c = $2; gsub(/[ \t`]/, "", c); if (c == id) { $(NF-1) = " `OBSOLETA` " } }
      { print }
    ' "$LL_FILE" > "$LL_FILE.tmp" && replace_file "$LL_FILE.tmp" "$LL_FILE"
    brain_sync
    say "${YELLOW}🗄  Lección retirada:${NC} $LL_ID marcada como OBSOLETA (ya no cuenta como antídoto vigente)."
    ;;

  prefer)
    [ "$#" -ge 3 ] || die "Uso: ./task.sh prefer \"<categoría>\" \"<regla>\""
    brain_prefer "$2" "$3"
    ;;

  brain)
    SUB="${2:-}"
    case "$SUB" in
      sync)
        require_file "$BRAIN_FILE" "Créalo desde .agents/templates/BRAIN_TEMPLATE.md."
        grep -qE "$HDR_LESSONS" "$BRAIN_FILE" || die "BRAIN.md no tiene la tabla de lecciones (cabecera '| ID | Fecha | Categoría | ...'); añádela desde .agents/templates/BRAIN_TEMPLATE.md."
        brain_sync
        say "${GREEN}🧠 BRAIN.md sincronizado${NC} desde .agents/brain/lessons_learned.md ($(all_lessons | wc -l | tr -d ' ') lecciones)."
        ;;
      scope)
        [ -n "${3:-}" ] && [ -n "${4:-}" ] || die "Uso: ./task.sh brain scope LL-001 \"<globs separados por comas | *>\""
        LL_ID=$(printf '%s' "$3" | tr '[:lower:]' '[:upper:]')
        [[ "$LL_ID" =~ ^LL-[0-9]+$ ]] || die "ID de lección inválido: '$3' (formato LL-001)."
        case "$4" in *$'\n'*|*$'\r'*|*'|'*) die "Ámbito inválido: usa globs separados por comas, sin '|' ni saltos de línea." ;; esac
        SCOPE=$(norm_scope "$4")
        [ -n "$SCOPE" ] || die "Ámbito vacío: indica al menos un glob, o '*' para una lección general."
        ensure_lessons_file
        ensure_lessons_schema
        adopt_brain_lessons
        grep -qE "^\|[[:space:]]*\`?$LL_ID\`?[[:space:]]*\|" "$LL_FILE" || die "$LL_ID no existe en $LL_FILE."
        SCOPE="$SCOPE" awk -F'|' -v OFS='|' -v id="$LL_ID" '
          /^\|/ { c = $2; gsub(/[ \t`]/, "", c); if (c == id) { $(NF-2) = " `" ENVIRON["SCOPE"] "` " } }
          { print }
        ' "$LL_FILE" > "$LL_FILE.tmp" && replace_file "$LL_FILE.tmp" "$LL_FILE"
        brain_sync
        say "${GREEN}🧠 Ámbito actualizado:${NC} $LL_ID -> $SCOPE"
        ;;
      search)
        shift 2
        case "$*" in *[![:space:]]*) ;; *) die "Uso: ./task.sh brain search <términos...>" ;; esac
        OUT=$(brain_search "$@")
        if [ -n "$OUT" ]; then
          say "🧠 Coincidencias para: $*"
          printf '%s\n' "$OUT"
        else
          say "🧠 Sin coincidencias para: $*"
        fi
        ;;
      for)
        require_state
        [ -n "${3:-}" ] || die "Uso: ./task.sh brain for TASK-001 [ruta...]"
        TASK_ID=$(normalize_id "$3")
        require_task "$TASK_ID"
        shift 3
        PATHS=""
        for pth in "$@"; do PATHS="${PATHS}${pth}"$'\n'; done
        AGENT=$(task_field "$TASK_ID" 4)
        REL=$(relevant_lessons "$(agent_category "$AGENT")" "$(task_field "$TASK_ID" 3) $(task_field "$TASK_ID" 7)" "$PATHS")
        say "🧠 Cerebro para $TASK_ID ($AGENT):"
        if [ -n "$REL" ]; then
          printf '%s\n' "$REL" | awk -F'\t' '{
            rc = ($6 != "") ? $6 + 0 : 0
            if (rc > 0) {
              printf "  ⚠️  %s [%s] (🚨 ALERTA CRÍTICA: %d reincidencias históricas) %s\n     ↳ Antídoto: %s\n     (motivo: %s)\n", $1, $2, rc, $3, $5, $4
            } else {
              printf "  %s [%s] %s\n     ↳ Antídoto: %s\n     (motivo: %s)\n", $1, $2, $3, $5, $4
            }
          }'
        else
          say "  Sin lecciones específicas para esta tarea."
        fi
        DEBTS=$(pending_debts | awk -F'\t' -v t="$TASK_ID" '$2 == t || $4 == "ALTA" { printf "  %s (%s, %s) %s\n", $1, $2, $4, $3 }')
        if [ -n "$DEBTS" ]; then
          say "📋 Deuda técnica pendiente relacionada o de prioridad ALTA:"
          printf '%s\n' "$DEBTS"
        fi
        ;;
      doctor)
        DOC_RC=0
        DOC=$(brain_doctor) || DOC_RC=1
        if [ -n "$DOC" ]; then
          printf '%s\n' "$DOC"
        fi
        if [ "$DOC_RC" -ne 0 ]; then
          die "El cerebro tiene errores que corregir (ver arriba)."
        fi
        say "${GREEN}🧠 Cerebro sano${NC}$( [ -n "$DOC" ] && printf ' (con avisos)' )."
        ;;
      stats)
        say "🧠 Estado del cerebro:"
        brain_stats
        ;;
      hotspots)
        brain_hotspots
        ;;
      lint)
        shift 2
        brain_lint "$@"
        ;;
      *)
        die "Uso: ./task.sh brain <sync | search <términos> | for TASK-ID [ruta...] | scope LL-ID \"<globs>\" | doctor | stats | hotspots | lint [ruta...]>"
        ;;
    esac
    ;;

  contracts)
    sub="${2:-validate}"
    case "$sub" in
      validate)
        C_FILE="${3:-$PROJECT_ROOT/contracts.json}"
        [ -f "$C_FILE" ] || die "Archivo de contratos no encontrado: $C_FILE"$'\n'"   Uso: ./task.sh contracts validate [ruta/contracts.json]"
        python3 -c '
import json, sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    sys.exit(f"❌ Error al leer o parsear JSON en {path}: {e}")

if not isinstance(data, dict):
    sys.exit(f"❌ El archivo de contratos debe ser un objeto JSON (dict), no {type(data).__name__}")

if "version" not in data:
    sys.exit("❌ Falta la clave obligatoria \"version\" en el contrato")

if "endpoints" not in data or not isinstance(data["endpoints"], list):
    sys.exit("❌ Falta la clave obligatoria \"endpoints\" o no es una lista")

valid_methods = {"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"}
for idx, ep in enumerate(data["endpoints"]):
    if not isinstance(ep, dict):
        sys.exit(f"❌ El endpoint en indice {idx} no es un objeto")
    method = ep.get("method")
    ep_path = ep.get("path")
    if not method or not isinstance(method, str) or method.upper() not in valid_methods:
        sys.exit(f"❌ Endpoint #{idx + 1} tiene metodo HTTP invalido: {method}")
    if not ep_path or not isinstance(ep_path, str) or not ep_path.startswith("/"):
        sys.exit(f"❌ Endpoint #{idx + 1} ({method}) tiene ruta invalida (debe empezar con /): {ep_path}")

count = len(data["endpoints"])
print(f"✅ Contratos válidos: {count} endpoints definidos en {path}")
' "$C_FILE" || exit 1
        ;;
      *)
        die "Comando contracts desconocido: '$sub'"$'\n'"   Uso: ./task.sh contracts validate [ruta/contracts.json]"
        ;;
    esac
    ;;

  swarm)
    sub="${2:-status}"
    case "$sub" in
      status|list)
        require_state
        say "${BLUE}${BOLD}=== Enjambre Multi-Agente (Swarm Status) ===${NC}"
        python3 -c '
import subprocess, sys, signal
if hasattr(signal, "SIGPIPE"):
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)

state_file = sys.argv[1]
is_list_only = (sys.argv[2] == "list")

wt_map = {}
try:
    res = subprocess.run(["git", "worktree", "list", "--porcelain"], capture_output=True, text=True)
    current_wt = None
    for line in res.stdout.splitlines():
        if line.startswith("worktree "):
            current_wt = line.split(" ", 1)[1]
        elif line.startswith("branch ") and current_wt:
            b = line.split(" ", 1)[1].replace("refs/heads/", "")
            wt_map[b] = current_wt
            current_wt = None
except Exception:
    pass

branches = []
try:
    res = subprocess.run(["git", "branch", "--format=%(refname:short)"], capture_output=True, text=True)
    branches = [b.strip() for b in res.stdout.splitlines() if b.strip()]
except Exception:
    pass

tasks = []
with open(state_file, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line.startswith("|"): continue
        parts = [p.strip().replace("`", "") for p in line.split("|")]
        if len(parts) >= 6:
            tid = parts[1]
            desc = parts[2]
            agent = parts[3]
            status = parts[4]
            if tid.startswith("TASK-") and tid[5:].isdigit():
                matching_branch = "-"
                for b in branches:
                    if tid.lower() in b.lower():
                        matching_branch = b
                        break
                workspace = wt_map.get(matching_branch, "main")
                tasks.append({
                    "id": tid,
                    "desc": desc,
                    "agent": agent,
                    "status": status,
                    "branch": matching_branch,
                    "workspace": workspace
                })

in_progress = [t for t in tasks if t["status"] in ("IN_PROGRESS", "AWAITING_HUMAN_APPROVAL", "IN_REVIEW_QA")]

if is_list_only:
    print("ID\tAGENTE\tESTADO\tRAMA\tWORKSPACE")
    for t in tasks:
        if t["status"] in ("IN_PROGRESS", "AWAITING_HUMAN_APPROVAL", "IN_REVIEW_QA", "TODO"):
            print("%s\t%s\t%s\t%s\t%s" % (t["id"], t["agent"], t["status"], t["branch"], t["workspace"]))
else:
    print("- Agentes activos concurrentes: %d" % len(in_progress))
    b_count = len([t for t in tasks if t["branch"] != "-"])
    print("- Ramas de tareas detectadas: %d" % b_count)
    print("- Workspaces aislados (worktrees): %d\n" % len(wt_map))
    if in_progress:
        print("| Tarea    | Agente                 | Estado      | Rama Git                         | Workspace |")
        print("| :---     | :---                   | :---        | :---                             | :---      |")
        for t in in_progress:
            print("| %-8s | %-22s | %-11s | %-32s | %s |" % (t["id"], t["agent"], t["status"], t["branch"], t["workspace"]))
    else:
        print("ℹ️  No hay agentes trabajando concurrentemente en este momento.")
' "$STATE_FILE" "$sub"
        ;;

      spawn)
        require_state
        TID="${3:-}"
        [ -n "$TID" ] || die "Falta el ID de tarea."$'\n'"   Uso: ./task.sh swarm spawn TASK-XXX [--workspace branch|share]"
        TID=$(normalize_id "$TID")
        require_task "$TID"

        CUR_STATUS=$(task_field "$TID" 5)
        if [ "$CUR_STATUS" = "TODO" ] || [ "$CUR_STATUS" = "BACKLOG" ]; then
          set_task "$TID" "IN_PROGRESS"
        fi

        DESC=$(task_field "$TID" 3)
        PREFIX="feature"
        case "$(printf '%s' "$DESC" | tr '[:upper:]' '[:lower:]')" in
          bug[:\ ]*|fix[:\ ]*|hotfix[:\ ]*) PREFIX="fix";      DESC="${DESC#*[: ]}" ;;
          refactor[:\ ]*)                   PREFIX="refactor"; DESC="${DESC#*[: ]}" ;;
        esac
        SLUG=$(printf '%s\n' "$DESC" | norm_text \
          | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c 1-30 | sed 's/-$//')
        BRANCH="$PREFIX/$TID-${SLUG:-tarea}"

        WS_DIR="$PROJECT_ROOT/.agents/workspaces/$TID"
        if [ -d "$WS_DIR" ]; then
          say "ℹ️  El workspace aislado ya existe en: $WS_DIR"
        else
          mkdir -p "$PROJECT_ROOT/.agents/workspaces"
          if in_git; then
            if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
              if [ "$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null)" = "$BRANCH" ]; then
                git -C "$PROJECT_ROOT" worktree add --detach "$WS_DIR" "$BRANCH" >/dev/null 2>&1 \
                  || git -C "$PROJECT_ROOT" worktree add "$WS_DIR" "$BRANCH" >/dev/null 2>&1
              else
                git -C "$PROJECT_ROOT" worktree add "$WS_DIR" "$BRANCH" >/dev/null 2>&1
              fi
            else
              git -C "$PROJECT_ROOT" worktree add -b "$BRANCH" "$WS_DIR" HEAD >/dev/null 2>&1 \
                || git -C "$PROJECT_ROOT" worktree add "$WS_DIR" -B "$BRANCH" HEAD >/dev/null 2>&1
            fi
          else
            mkdir -p "$WS_DIR"
          fi
          say "🐝 Enjambre: Workspace aislado creado para $TID"
          say "   Directorio: $WS_DIR"
          say "   Rama activa: $BRANCH"
        fi
        ;;

      clean)
        require_state
        TID="${3:-}"
        if [ -n "$TID" ]; then
          TID=$(normalize_id "$TID")
          WS_DIR="$PROJECT_ROOT/.agents/workspaces/$TID"
          if [ -d "$WS_DIR" ]; then
            git worktree remove "$WS_DIR" --force 2>/dev/null || rm -rf "$WS_DIR"
            git worktree prune 2>/dev/null || true
            say "🧹 Workspace de $TID limpiado exitosamente."
          else
            say "ℹ️  No existe workspace para $TID."
          fi
        else
          if [ -d "$PROJECT_ROOT/.agents/workspaces" ]; then
            for wdir in "$PROJECT_ROOT/.agents/workspaces"/*; do
              if [ -d "$wdir" ]; then
                git worktree remove "$wdir" --force 2>/dev/null || rm -rf "$wdir"
              fi
            done
            rm -rf "$PROJECT_ROOT/.agents/workspaces"
            git worktree prune 2>/dev/null || true
            say "🧹 Todos los workspaces del enjambre han sido limpiados."
          else
            say "ℹ️  No hay workspaces activos para limpiar."
          fi
        fi
        ;;

      *)
        die "Comando swarm desconocido: '$sub'"$'\n'"   Uso: ./task.sh swarm [status|list|spawn TASK-XXX|clean [TASK-XXX]]"
        ;;
    esac
    ;;

  help|-h|--help|*)
    # Un comando desconocido (errata como 'clsoe') no puede parecer un éxito: ayuda por stderr y exit 1
    HELP_RC=0
    case "$COMMAND" in
      help|-h|--help) ;;
      *)
        exec 1>&2
        [ -t 2 ] || { RED=""; NC=""; }
        printf '%s\n' "${RED}❌ Error: comando desconocido '$COMMAND'.${NC}"
        HELP_RC=1
        ;;
    esac
    cat <<'EOF'
=================================================================
  CLI de Gestión de Tareas y Cerebro Multi-Agente (task.sh)
=================================================================
  list                                   Ver el tablero
  metrics                                Progreso y salud de QA
  doctor                                 Diagnóstico integral (estado, cerebro, secretos y skills)
  diff [TASK-ID] [--stat]                Diff y estadísticas de la tarea frente a main
  dashboard [--output ruta]              Genera un visor visual interactivo (HTML) del proyecto
  serve [--port N]                       Inicia servidor local con Live Dashboard y acciones en tiempo real
  hold TASK-ID ["motivo"]                Pausa una tarea para aprobación humana (AWAITING_HUMAN_APPROVAL)
  approve TASK-ID [--status S] [--comment C]  Aprueba y reanuda una tarea (S: TODO o IN_PROGRESS)
  add "<desc>" "<agente>" "<criterios>"  Crear tarea (TODO)
  start TASK-ID                          TODO/rechazada -> IN_PROGRESS + rama Git
  handoff TASK-ID [revisor] [--verify "cmd"]...  IN_PROGRESS -> IN_REVIEW_QA + JSON + historial
                                         (revisor: quien recibe la entrega; por defecto qa-security-agent)
  reject TASK-ID "<motivo>"              QA rechaza (+1); a 3/3 -> BLOCKED
  close TASK-ID [--lesson LL-ID | --no-lesson "<motivo>"]
                                         QA aprueba: IN_REVIEW_QA -> DONE (lección obligatoria si la
                                         tarea fue rechazada o corrige un defecto)
  move TASK-ID <TODO|BACKLOG>            Replanificar o desbloquear (BLOCKED también -> IN_PROGRESS)
  archive [--keep N] [--phase "<fase>"]  Archiva tareas DONE en .agents/archive/ (conserva N recientes)
  commit TASK-ID "<msg>" [tipo] [--trailer "Clave: valor"]...
                                         Commit con formato tipo(TASK-ID): msg (trailers de autoría
                                         también con MAESTRO_COMMIT_TRAILER)
  learn "<problema>" [cat] ["<causa>"] ["<solución>"] [--paths "<globs>"] [--force]
                                         Lección en lessons_learned.md (fuente única; rechaza
                                         duplicados salvo --force)
  debt "<desc>" TASK-ID "<acción>" [ALTA|MEDIA|BAJA]    Deuda técnica
  contracts [validate] [ruta]            Valida contratos API y DTOs (contracts.json por defecto)
  swarm [status|list|spawn|clean]        Coordina enjambres concurrentes de agentes y workspaces aislados
  check <ruta> [ruta...]                 Antes de editar: tarea activa (cero código sin tarea) y lecciones
                                         de esas rutas; exit 2 si alguna está bloqueada (Antigravity)
  brain search <términos...>             Busca en lecciones, gotchas y deuda
  brain for TASK-ID [ruta...]            Lecciones y deuda relevantes para una tarea (y rutas)
  brain scope LL-ID "<globs>"            Fija a qué rutas aplica una lección
  brain sync                             Regenera la tabla de BRAIN.md desde lessons_learned.md
  brain doctor                           Valida el cerebro (columnas, IDs duplicados, estados, sincronía)
  brain stats                            Lecciones por categoría, reincidencias y deuda
  brain hotspots                         Identifica hotspots de riesgo según lecciones y reincidencias
  brain lint [ruta...]                   Audita activamente antipatrones aprendidos en el código
  prefer "<categoría>" "<regla>"         Registra una preferencia en .agents/brain/preferences.md
  debt-resolve TD-ID                     Deuda saldada: la marca SALDADA y la retira de BRAIN.md
  lesson-retire LL-ID                    Marca una lección como OBSOLETA
=================================================================
EOF
    exit "$HELP_RC"
    ;;
esac
