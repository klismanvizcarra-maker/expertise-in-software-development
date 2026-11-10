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

VALID_STATUSES="BACKLOG|TODO|IN_PROGRESS|IN_REVIEW_QA|BLOCKED|DONE"
MAX_ITERATIONS=3

# Encabezados que identifican cada tabla (las filas nuevas se añaden al final de la tabla)
HDR_TASKS='^\|[ \t]*ID Tarea[ \t]*\|'
HDR_HISTORY='^\|[ \t]*Fecha[ \t]*\|[ \t]*Agente Emisor'
HDR_LESSONS='^\|[ \t]*ID[ \t]*\|[ \t]*Fecha[ \t]*\|[ \t]*Categor'
HDR_DEBT='^\|[ \t]*ID[ \t]*\|[ \t]*Tarea Vinculada'

COMMAND="${1:-help}"
TODAY=$(date +"%Y-%m-%d")

# Colores ANSI (desactivados si la salida no es una terminal)
if [ -t 1 ]; then
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
die()  { printf '%s\n' "${RED}❌ Error: $*${NC}" >&2; exit 1; }

# Sustituye FILE por el contenido de TMP conservando permisos e inodo del original
# (mv dejaría el archivo con los permisos 0600 de mktemp)
replace_file() {
  local tmp="$1" file="$2"
  cat "$tmp" > "$file" && rm -f "$tmp"
}

# Biblioteca del cerebro: norm_text, lecciones (fuente única), relevancia y búsqueda
# shellcheck source=brain-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/brain-lib.sh"

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
  local timeout=200 # 200 * 0.05s = 10s
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
  trap 'release_lock' EXIT INT TERM
}

require_file() {
  [ -f "$1" ] || die "No existe $1."$'\n'"   $2"
}

require_state() {
  require_file "$STATE_FILE" "Créalo con /iniciar-proyecto o con .agents/scripts/init-project.sh."
}

# Texto seguro para una celda de tabla Markdown: sin barras verticales ni saltos de línea
cell() {
  printf '%s' "$1" | tr '\n\r|' '  /'
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

# Siguiente ID con prefijo (TASK, LL, TD) buscando en todos los archivos indicados
next_id() {
  local prefix="$1"; shift
  local max
  max=$(cat "$@" 2>/dev/null | grep -oE "${prefix}-[0-9]+" | sed "s/${prefix}-//" | sort -n | tail -1)
  printf "%s-%03d" "$prefix" $((10#${max:-0} + 1))
}

# Imprime las filas del tablero de tareas (columna 1 = TASK-NNN)
board_rows() {
  awk -F'|' '
    /^\|/ {
      id = $2; gsub(/[ \t`]/, "", id)
      if (id ~ /^TASK-[0-9]+$/) print
    }
  ' "$STATE_FILE"
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
  [ -n "$(task_field "$1" 2)" ] || die "La tarea $1 no existe en el tablero de $STATE_FILE."
}

# Iteraciones de QA consumidas (número antes de /3)
task_iteration() {
  local it
  it=$(task_field "$1" 6 | cut -d/ -f1)
  [[ "$it" =~ ^[0-9]+$ ]] || it=0
  printf '%s' "$it"
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
  add|start|move|handoff|reject|close|learn|debt|debt-resolve|lesson-retire|brain)
    acquire_lock
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

    NEXT_ID=$(next_id TASK "$STATE_FILE")
    append_to_table "$STATE_FILE" "$HDR_TASKS" \
      "| \`$NEXT_ID\` | $(cell "$DESC") | $(cell "$AGENT") | \`TODO\` | \`0/$MAX_ITERATIONS\` | $(cell "$CRITERIA") |"
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
          for (i = 1; i <= nr; i++) if (r[i] != "") { split(r[i], f, "\t"); seen[f[1]] = 1; printf "     %s  [%s] %s  (%s)\n", f[1], f[2], substr(f[3], 1, 90), f[4]; shown++ }
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
    [ -n "$2" ] && [ -n "$3" ] || die "Uso: ./task.sh move TASK-001 <TODO|BACKLOG> (o IN_PROGRESS al desbloquear una tarea BLOCKED)"
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
        [ "$CURRENT" = "BLOCKED" ] \
          || die "$TASK_ID no puede pasar de $CURRENT a IN_PROGRESS con move: usa 'task.sh start $TASK_ID' (crea o cambia a su rama)." ;;
    esac
    if [ "$CURRENT" = "BLOCKED" ]; then
      # Salir de BLOCKED implica una decisión humana: se reinicia el contador de QA
      set_task "$TASK_ID" "$NEW_STATUS" "0/$MAX_ITERATIONS"
      log_history "orchestrator-agent" "Equipo" "$TASK_ID" "Desbloqueada tras decisión humana -> $NEW_STATUS"
    else
      set_task "$TASK_ID" "$NEW_STATUS"
      # Replanificar (incluido reabrir una tarea DONE) también deja rastro en el historial
      if [ "$CURRENT" != "$NEW_STATUS" ]; then
        log_history "orchestrator-agent" "Equipo" "$TASK_ID" "Replanificada $CURRENT -> $NEW_STATUS"
      fi
    fi
    say "${GREEN}✅ Estado actualizado:${NC} $TASK_ID ahora está en $NEW_STATUS"
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

    # Archivos entregados: cambios de la rama respecto a main/master + cambios sin commitear
    FILES=""
    if in_git; then
      BASE=""
      for b in main master; do
        if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$b"; then BASE="$b"; break; fi
      done
      if [ -n "$BASE" ] && [ "$(git -C "$PROJECT_ROOT" branch --show-current)" != "$BASE" ]; then
        MB=$(git -C "$PROJECT_ROOT" merge-base HEAD "$BASE" 2>/dev/null || true)
        [ -n "$MB" ] && FILES=$(git -C "$PROJECT_ROOT" diff --name-only "$MB" HEAD)
      fi
      UNCOMMITTED=$(git -C "$PROJECT_ROOT" status --porcelain --untracked-files=all | cut -c4- | sed 's/.* -> //')
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
    ;;

  close)
    require_state
    [ -n "$2" ] || die "Uso: ./task.sh close TASK-001"
    TASK_ID=$(normalize_id "$2")
    require_task "$TASK_ID"
    STATUS=$(task_field "$TASK_ID" 5)
    [ "$STATUS" = "IN_REVIEW_QA" ] || die "$TASK_ID está en $STATUS; solo QA cierra tareas en IN_REVIEW_QA (cero bypasses de QA)."

    REVIEW_FILE="$PROJECT_ROOT/.agents/reviews/qa_$TASK_ID.md"
    [ -f "$REVIEW_FILE" ] || die "Falta el archivo de veredicto .agents/reviews/qa_$TASK_ID.md. Ejecuta /qa-review antes de cerrar la tarea."

    REVIEWER=$(grep -Ei '^[[:space:]]*[-*]?[[:space:]]*\*{0,2}Revisor\*{0,2}:' "$REVIEW_FILE" 2>/dev/null | head -n1 | sed -E 's/.*:[[:space:]]*`?([a-zA-Z0-9_-]+)`?.*/\1/' | tr -d '[:space:]')
    [ -n "$REVIEWER" ] || die "No se encontró el campo 'Revisor' en $REVIEW_FILE."

    ASSIGNED=$(task_field "$TASK_ID" 4)
    [ "$REVIEWER" != "$ASSIGNED" ] || die "El revisor ($REVIEWER) no puede ser el mismo agente asignado a la tarea ($ASSIGNED). Se requiere revisión por un agente independiente (cero auto-aprobación)."

    set_task "$TASK_ID" "DONE"
    log_history "$REVIEWER" "orchestrator-agent" "$TASK_ID" "Aprobada por QA -> DONE"
    say "${GREEN}✅ $TASK_ID aprobada y cerrada (DONE).${NC}"
    if in_git; then
      BRANCH=$(git -C "$PROJECT_ROOT" branch --list "*$TASK_ID*" 2>/dev/null | tr -d '* ' | head -n1)
      if [ -n "$BRANCH" ]; then
        say "${CYAN}💡 Comando de fusión y limpieza:${NC}"
        say "   git checkout main && git merge --no-ff $BRANCH && git branch -d $BRANCH"
      fi
    fi
    ;;

  metrics)
    require_state
    ROWS=$(board_rows)
    TOTAL=$(printf '%s' "$ROWS" | grep -c '^|' || true)
    if [ "${TOTAL:-0}" -eq 0 ]; then say "No hay tareas registradas."; exit 0; fi

    count_status() { printf '%s\n' "$ROWS" | awk -F'|' -v s="$1" '{ v=$5; gsub(/[ \t`]/,"",v); if (v==s) n++ } END { print n+0 }'; }
    count_iter()   { printf '%s\n' "$ROWS" | awk -F'|' -v s="$1" '{ v=$6; gsub(/[ \t`]/,"",v); if (v==s) n++ } END { print n+0 }'; }

    DONE=$(count_status DONE); IN_PROG=$(count_status IN_PROGRESS); IN_QA=$(count_status IN_REVIEW_QA)
    TODO=$(count_status TODO); BACKLOG=$(count_status BACKLOG); BLOCKED=$(count_status BLOCKED)
    PCT=$((DONE * 100 / TOTAL)); FILLED=$((PCT * 20 / 100)); BAR=""
    for ((i=0; i<20; i++)); do if [ $i -lt $FILLED ]; then BAR="${BAR}█"; else BAR="${BAR}░"; fi; done

    say "${BLUE}${BOLD}=== Métricas del Proyecto ===${NC}"
    say "Progreso: [${GREEN}${BAR}${NC}] ${BOLD}${PCT}%${NC} ($DONE de $TOTAL tareas)"
    say ""
    say "  - ${GREEN}DONE:${NC}         $DONE"
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
    require_file "$LL_FILE" "Créalo desde .agents/templates/lessons_learned_template.md."
    ensure_lessons_schema
    CAT_UPPER=$(printf '%s' "$CAT" | tr '[:lower:]' '[:upper:]')
    SCOPE=$(printf '%s' "$SCOPE" | tr -d ' `')
    case "$SCOPE" in *$'\n'*|*'|'*) die "Ámbito inválido: usa globs separados por comas, sin '|' ni saltos de línea." ;; esac
    [ -n "$SCOPE" ] || SCOPE='*'

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
    say "${YELLOW}📋 Deuda técnica registrada:${NC} $NEXT_ID -> $DESC (vinculada a $TASK_ID)"
    ;;

  debt-resolve)
    [ -n "${2:-}" ] || die "Uso: ./task.sh debt-resolve TD-001"
    TD_ID=$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')
    [[ "$TD_ID" =~ ^TD-[0-9]+$ ]] || die "ID de deuda inválido: '$2' (formato TD-001)."
    require_file "$DEBT_FILE" "Créalo desde .agents/templates/tech_debt_template.md."
    grep -qE "^\|[[:space:]]*\`?$TD_ID\`?[[:space:]]*\|" "$DEBT_FILE" || die "$TD_ID no existe en $DEBT_FILE."
    # tech_debt.md conserva la fila marcada SALDADA (así el ID no se reutiliza y queda la traza);
    # del resumen de BRAIN.md se elimina
    if awk -F'|' -v id="$TD_ID" '/^\|/ { c = $2; gsub(/[ \t`]/, "", c); if (c == id) { p = $(NF-1); gsub(/[ \t`]/, "", p); if (p == "SALDADA") f = 1 } } END { exit !f }' "$DEBT_FILE"; then
      die "$TD_ID ya estaba marcada como SALDADA."
    fi
    awk -F'|' -v OFS='|' -v id="$TD_ID" '
      /^\|/ { c = $2; gsub(/[ \t`]/, "", c); if (c == id) { $(NF-1) = " `SALDADA` " } }
      { print }
    ' "$DEBT_FILE" > "$DEBT_FILE.tmp" && replace_file "$DEBT_FILE.tmp" "$DEBT_FILE"
    if [ -f "$BRAIN_FILE" ]; then
      awk -F'|' -v id="$TD_ID" '{ c = $2; gsub(/[ \t`]/, "", c); if (/^\|/ && c == id) next; print }' "$BRAIN_FILE" > "$BRAIN_FILE.tmp" && replace_file "$BRAIN_FILE.tmp" "$BRAIN_FILE"
    fi
    say "${GREEN}✅ Deuda técnica saldada:${NC} $TD_ID marcada SALDADA en tech_debt.md y retirada de BRAIN.md."
    ;;

  lesson-retire)
    [ -n "${2:-}" ] || die "Uso: ./task.sh lesson-retire LL-001"
    LL_ID=$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')
    [[ "$LL_ID" =~ ^LL-[0-9]+$ ]] || die "ID de lección inválido: '$2' (formato LL-001)."
    require_file "$LL_FILE" "Créalo desde .agents/templates/lessons_learned_template.md."
    ensure_lessons_schema
    grep -qE "^\|[[:space:]]*\`?$LL_ID\`?[[:space:]]*\|" "$LL_FILE" || die "$LL_ID no existe en $LL_FILE."
    awk -F'|' -v OFS='|' -v id="$LL_ID" '
      /^\|/ { c = $2; gsub(/[ \t`]/, "", c); if (c == id) { $(NF-1) = " `OBSOLETA` " } }
      { print }
    ' "$LL_FILE" > "$LL_FILE.tmp" && replace_file "$LL_FILE.tmp" "$LL_FILE"
    brain_sync
    say "${YELLOW}🗄  Lección retirada:${NC} $LL_ID marcada como OBSOLETA (ya no cuenta como antídoto vigente)."
    ;;

  brain)
    SUB="${2:-}"
    case "$SUB" in
      sync)
        require_file "$LL_FILE" "Créalo desde .agents/templates/lessons_learned_template.md."
        brain_sync
        say "${GREEN}🧠 BRAIN.md sincronizado${NC} desde .agents/brain/lessons_learned.md ($(all_lessons | wc -l | tr -d ' ') lecciones)."
        ;;
      scope)
        [ -n "${3:-}" ] && [ -n "${4:-}" ] || die "Uso: ./task.sh brain scope LL-001 \"<globs separados por comas | *>\""
        LL_ID=$(printf '%s' "$3" | tr '[:lower:]' '[:upper:]')
        [[ "$LL_ID" =~ ^LL-[0-9]+$ ]] || die "ID de lección inválido: '$3' (formato LL-001)."
        SCOPE=$(printf '%s' "$4" | tr -d ' `')
        case "$SCOPE" in *$'\n'*|*'|'*|'') die "Ámbito inválido: usa globs separados por comas, sin '|' ni saltos de línea." ;; esac
        require_file "$LL_FILE" "Créalo desde .agents/templates/lessons_learned_template.md."
        ensure_lessons_schema
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
        [ $# -gt 0 ] || die "Uso: ./task.sh brain search <términos...>"
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
          printf '%s\n' "$REL" | awk -F'\t' '{ printf "  %s [%s] %s\n     ↳ %s\n     (motivo: %s)\n", $1, $2, $3, $5, $4 }'
        else
          say "  Sin lecciones específicas para esta tarea."
        fi
        DEBTS=$(pending_debts | awk -F'\t' -v t="$TASK_ID" '$2 == t || $4 == "ALTA" { printf "  %s (%s, %s) %s\n", $1, $2, $4, $3 }')
        if [ -n "$DEBTS" ]; then
          say "📋 Deuda técnica pendiente relacionada o de prioridad ALTA:"
          printf '%s\n' "$DEBTS"
        fi
        ;;
      *)
        die "Uso: ./task.sh brain <sync | search <términos> | for TASK-ID [ruta...] | scope LL-ID \"<globs>\">"
        ;;
    esac
    ;;

  help|-h|--help|*)
    cat <<'EOF'
=================================================================
  CLI de Gestión de Tareas y Cerebro Multi-Agente (task.sh)
=================================================================
  list                                   Ver el tablero
  metrics                                Progreso y salud de QA
  add "<desc>" "<agente>" "<criterios>"  Crear tarea (TODO)
  start TASK-ID                          TODO/rechazada -> IN_PROGRESS + rama Git
  handoff TASK-ID [revisor] [--verify "cmd"]...  IN_PROGRESS -> IN_REVIEW_QA + JSON + historial
                                         (revisor: quien recibe la entrega; por defecto qa-security-agent)
  reject TASK-ID "<motivo>"              QA rechaza (+1); a 3/3 -> BLOCKED
  close TASK-ID                          QA aprueba: IN_REVIEW_QA -> DONE
  move TASK-ID <TODO|BACKLOG>            Replanificar o desbloquear (BLOCKED también -> IN_PROGRESS)
  commit TASK-ID "<msg>" [tipo] [--trailer "Clave: valor"]...
                                         Commit con formato tipo(TASK-ID): msg (trailers de autoría
                                         también con MAESTRO_COMMIT_TRAILER)
  learn "<problema>" [cat] ["<causa>"] ["<solución>"] [--paths "<globs>"] [--force]
                                         Lección en lessons_learned.md (fuente única; rechaza
                                         duplicados salvo --force)
  debt "<desc>" TASK-ID "<acción>" [ALTA|MEDIA|BAJA]    Deuda técnica
brain search <términos...>             Busca en lecciones, gotchas y deuda
  brain for TASK-ID [ruta...]            Lecciones y deuda relevantes para una tarea (y rutas)
  brain scope LL-ID "<globs>"            Fija a qué rutas aplica una lección
  brain sync                             Regenera la tabla de BRAIN.md desde lessons_learned.md
    debt-resolve TD-ID                     Deuda saldada: la marca SALDADA y la retira de BRAIN.md
  lesson-retire LL-ID                    Marca una lección como OBSOLETA
=================================================================
EOF
    ;;
esac
