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
  GREEN="\033[0;32m"; BLUE="\033[0;34m"; YELLOW="\033[1;33m"; RED="\033[0;31m"
  CYAN="\033[0;36m"; BOLD="\033[1m"; NC="\033[0m"
else
  GREEN=""; BLUE=""; YELLOW=""; RED=""; CYAN=""; BOLD=""; NC=""
fi

# ------------------------------------------------------------------------------
# Utilidades
# ------------------------------------------------------------------------------

say()  { printf "%b\n" "$*"; }
die()  { printf "%b\n" "${RED}❌ Error: $*${NC}" >&2; exit 1; }

require_file() {
  [ -f "$1" ] || die "No existe $1.\n   $2"
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
  mv "$tmp" "$STATE_FILE"
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
  mv "$tmp" "$file"
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
      die "Faltan parámetros.\n   Uso: ./task.sh add \"<descripción>\" \"<agente>\" \"<criterios de aceptación>\""
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
      SLUG=$(printf '%s' "$DESC" | tr '[:upper:]' '[:lower:]' | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
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
    fi
    say "${GREEN}✅ Estado actualizado:${NC} $TASK_ID ahora está en $NEW_STATUS"
    ;;

  handoff)
    require_state
    [ -n "$2" ] || die "Uso: ./task.sh handoff TASK-001 [agente-destino]"
    TASK_ID=$(normalize_id "$2")
    TARGET_AGENT="${3:-qa-security-agent}"
    require_task "$TASK_ID"
    STATUS=$(task_field "$TASK_ID" 5)
    [ "$STATUS" = "IN_PROGRESS" ] || die "$TASK_ID está en $STATUS; solo se entrega desde IN_PROGRESS (usa 'task.sh start' primero)."

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
    "./.agents/scripts/validate-state.sh"
  ]
}
EOF

    set_task "$TASK_ID" "IN_REVIEW_QA"
    say "${GREEN}📦 Handoff generado:${NC} ${HANDOFF_FILE#$PROJECT_ROOT/}"
    say "   $TASK_ID -> ${BOLD}IN_REVIEW_QA${NC} (iteración $ITERATION/$MAX_ITERATIONS), revisa: ${CYAN}$TARGET_AGENT${NC}"
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
    set_task "$TASK_ID" "DONE"
    log_history "qa-security-agent" "orchestrator-agent" "$TASK_ID" "Aprobada por QA -> DONE"
    say "${GREEN}✅ $TASK_ID aprobada y cerrada (DONE).${NC}"
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
    [ -n "$2" ] && [ -n "$3" ] || die "Uso: ./task.sh commit TASK-001 \"descripción\" [feat|fix|test|refactor|docs|perf|chore|style|build|ci]"
    TASK_ID=$(normalize_id "$2")
    MSG="$3"
    TYPE="${4:-feat}"
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
    git -C "$PROJECT_ROOT" commit -m "$FULL_MSG"
    ;;

  learn)
    DESC="$2"
    CAT="${3:-general}"
    CAUSE="${4:-Por documentar}"
    FIX="${5:-Por documentar}"
    [ -n "$DESC" ] || die "Uso: ./task.sh learn \"<problema>\" [categoría] [\"<causa raíz>\"] [\"<solución>\"]"
    require_file "$BRAIN_FILE" "Créalo desde .agents/templates/BRAIN_TEMPLATE.md."
    CAT_UPPER=$(printf '%s' "$CAT" | tr '[:lower:]' '[:upper:]')

    NEXT_ID=$(next_id LL "$BRAIN_FILE" "$LL_FILE")
    BASE_ROW="| \`$NEXT_ID\` | $TODAY | \`[$(cell "$CAT_UPPER")]\` | $(cell "$DESC") | $(cell "$CAUSE") | $(cell "$FIX") |"
    append_to_table "$BRAIN_FILE" "$HDR_LESSONS" "$BASE_ROW \`ACTIVO\` |"
    # lessons_learned.md no tiene columna de Estado
    [ -f "$LL_FILE" ] && append_to_table "$LL_FILE" "$HDR_LESSONS" "$BASE_ROW"
    say "${GREEN}🧠 Lección registrada:${NC} $NEXT_ID -> [$CAT_UPPER] $DESC"
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

  help|-h|--help|*)
    cat <<'EOF'
=================================================================
  CLI de Gestión de Tareas y Cerebro Multi-Agente (task.sh)
=================================================================
  list                                   Ver el tablero
  metrics                                Progreso y salud de QA
  add "<desc>" "<agente>" "<criterios>"  Crear tarea (TODO)
  start TASK-ID                          TODO/rechazada -> IN_PROGRESS + rama Git
  handoff TASK-ID [agente]               IN_PROGRESS -> IN_REVIEW_QA + JSON de entrega
  reject TASK-ID "<motivo>"              QA rechaza (+1); a 3/3 -> BLOCKED
  close TASK-ID                          QA aprueba: IN_REVIEW_QA -> DONE
  move TASK-ID <TODO|BACKLOG>            Replanificar o desbloquear (BLOCKED también -> IN_PROGRESS)
  commit TASK-ID "<msg>" [tipo]          Commit con formato tipo(TASK-ID): msg
  learn "<problema>" [cat] ["<causa>"] ["<solución>"]   Lección en BRAIN.md
  debt "<desc>" TASK-ID "<acción>" [ALTA|MEDIA|BAJA]    Deuda técnica
=================================================================
EOF
    ;;
esac
