#!/usr/bin/env bash
# ==============================================================================
# Script de Auditoría de Estado Global (GLOBAL_STATE.md)
# ==============================================================================
# Verifica la integridad del tablero de tareas y alerta sobre deadlocks.
# Sale con código 1 si hay filas mal formadas (estado o iteración inválidos).
# ==============================================================================

set -euo pipefail

STATE_FILE="${1:-GLOBAL_STATE.md}"

echo "=== Auditando: $STATE_FILE ==="

if [ ! -f "$STATE_FILE" ]; then
  echo "❌ ERROR: No se encontró el archivo $STATE_FILE en la ruta especificada."
  exit 1
fi

ERRORS=0
WARNINGS=0

# Filas del tablero normalizadas: ID|ESTADO|ITERACION
ROWS=$(awk -F'|' '
  /^\|/ {
    id = $2; gsub(/[ \t`]/, "", id)
    if (id !~ /^TASK-[0-9]+$/) next
    st = $5; gsub(/[ \t`]/, "", st)
    it = $6; gsub(/[ \t`]/, "", it)
    print id "|" st "|" it
  }
' "$STATE_FILE")

ARCHIVE_DIR="$(cd "$(dirname "$STATE_FILE")" 2>/dev/null && pwd)/.agents/archive"
ARCHIVE_FILES=()
if [ -d "$ARCHIVE_DIR" ]; then
  for af in "$ARCHIVE_DIR"/*.md; do
    [ -f "$af" ] && ARCHIVE_FILES+=("$af")
  done
fi
ARCHIVE_ROWS=""
if [ "${#ARCHIVE_FILES[@]}" -gt 0 ]; then
  ARCHIVE_ROWS=$(awk -F'|' '
    /^\|/ {
      id = $2; gsub(/[ \t`]/, "", id)
      if (id !~ /^TASK-[0-9]+$/) next
      st = $5; gsub(/[ \t`]/, "", st)
      it = $6; gsub(/[ \t`]/, "", it)
      print id "|" st "|" it
    }
  ' "${ARCHIVE_FILES[@]}")
fi

ALL_ROWS=$(printf '%s\n%s\n' "$ROWS" "$ARCHIVE_ROWS" | grep -v '^$' || true)

# 1. Filas mal formadas e IDs duplicados
echo "-> Verificando formato del tablero..."
BAD=$(printf '%s\n' "$ROWS" | awk -F'|' 'NF == 3 && ($2 !~ /^(BACKLOG|TODO|IN_PROGRESS|IN_REVIEW_QA|AWAITING_HUMAN_APPROVAL|BLOCKED|DONE)$/ || $3 !~ /^[0-3]\/3$/) { print "   " $0 }')
BAD_ARCH=$(printf '%s\n' "$ARCHIVE_ROWS" | awk -F'|' 'NF == 3 && ($2 != "DONE" || $3 !~ /^[0-3]\/3$/) { print "   [archivo] " $0 }')
[ -n "$BAD_ARCH" ] && BAD=$(printf '%s\n%s\n' "$BAD" "$BAD_ARCH" | grep -v '^$' || true)
DUP_TASKS=$(printf '%s\n' "$ALL_ROWS" | awk -F'|' 'NF == 3 { c[$1]++ } END { for (id in c) if (c[id] > 1) print "   " id " (" c[id] " veces)" }' | sort || true)
if [ -n "$BAD" ]; then
  echo "❌ Filas con estado o iteración inválidos (ID|ESTADO|ITERACIÓN):"
  echo "$BAD"
  ERRORS=$((ERRORS + 1))
fi
if [ -n "$DUP_TASKS" ]; then
  echo "❌ IDs de tarea duplicados (tablero / .agents/archive/):"
  echo "$DUP_TASKS"
  ERRORS=$((ERRORS + 1))
fi
if [ -z "$BAD" ] && [ -z "$DUP_TASKS" ]; then
  echo "   [OK] Todas las tareas tienen ID único, estado e iteración válidos."
fi

# 2. Regla de 3 iteraciones y agentes conocidos
echo "-> Verificando regla de 3 iteraciones..."
DEADLOCKS=$(printf '%s\n' "$ROWS" | awk -F'|' '$3 == "3/3" || $2 == "BLOCKED" { print "   " $1 " (" $2 ", " $3 ")" }')
if [ -n "$DEADLOCKS" ]; then
  echo "⚠️  ADVERTENCIA DE DEADLOCK DETECTADA:"
  echo "$DEADLOCKS"
  echo "   -> Estas tareas requieren ESCALAMIENTO AL HUMANO antes de continuar."
  WARNINGS=$((WARNINGS + 1))
else
  echo "   [OK] Ninguna tarea bloqueada por el límite de iteraciones."
fi

SKILLS_DIR="$(cd "$(dirname "$STATE_FILE")" 2>/dev/null && pwd)/.agents/skills"
if [ -d "$SKILLS_DIR" ]; then
  UNKNOWN_AGENTS=$(awk -F'|' '
    /^\|/ {
      id = $2; gsub(/[ \t`]/, "", id)
      if (id !~ /^TASK-[0-9]+$/) next
      ag = $4; gsub(/`/, "", ag); gsub(/^[ \t]+|[ \t]+$/, "", ag)
      st = $5; gsub(/[ \t`]/, "", st)
      if (st != "DONE" && ag != "" && ag != "Equipo") print id "|" ag
    }
  ' "$STATE_FILE" | while IFS='|' read -r tid tag; do
    [ -d "$SKILLS_DIR/$tag" ] || printf '   %s -> %s\n' "$tid" "$tag"
  done)
  if [ -n "$UNKNOWN_AGENTS" ]; then
    echo "⚠️  Tareas activas con agente sin skill en .agents/skills/:"
    echo "$UNKNOWN_AGENTS"
    N_UNK=$(printf '%s\n' "$UNKNOWN_AGENTS" | grep -c . || true)
    WARNINGS=$((WARNINGS + N_UNK))
  fi
fi

# 3. Resumen
ACTIVE_DONE=$(printf '%s\n' "$ROWS" | awk -F'|' '$2 == "DONE" { n++ } END { print n+0 }')
ARCHIVED_DONE=$(printf '%s\n' "$ARCHIVE_ROWS" | awk -F'|' '$2 == "DONE" { n++ } END { print n+0 }')
DONE_TASKS=$((ACTIVE_DONE + ARCHIVED_DONE))
if [ "$ARCHIVED_DONE" -gt 0 ]; then
  echo "   [INFO] Tareas completadas (DONE): $DONE_TASKS ($ACTIVE_DONE activas, $ARCHIVED_DONE archivadas)"
else
  echo "   [INFO] Tareas completadas (DONE): $DONE_TASKS"
fi

# 3b. Salud del cerebro (lecciones y deuda): errores estructurales cuentan como errores
TASK_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/task.sh"
if [ -f "$TASK_SH" ] && [ -f "$(dirname "$STATE_FILE")/BRAIN.md" ]; then
  echo "-> Verificando el cerebro (lecciones y deuda)..."
  BRAIN_OUT=$(cd "$(dirname "$STATE_FILE")" && bash "$TASK_SH" brain doctor 2>&1) || true
  BRAIN_ERR=$(printf '%s\n' "$BRAIN_OUT" | grep -c '^ERROR' || true)
  BRAIN_WARN=$(printf '%s\n' "$BRAIN_OUT" | grep -c '^AVISO' || true)
  { printf '%s\n' "$BRAIN_OUT" | grep -E '^(ERROR|AVISO)' | sed 's/^/   /'; } || true
  if [ "$BRAIN_ERR" -gt 0 ]; then
    ERRORS=$((ERRORS + BRAIN_ERR))
  else
    echo "   [OK] Cerebro sin errores estructurales."
  fi
  WARNINGS=$((WARNINGS + BRAIN_WARN))
fi

# 4. Placeholders sin rellenar en metadatos
echo "-> Verificando placeholders pendientes..."
if grep -qE '\[NOMBRE_DEL_PROYECTO\]|\[Framework:|\[Breve descripción' "$STATE_FILE"; then
  echo "ℹ️  Nota: Existen campos de configuración pendientes de personalizar (usa /iniciar-proyecto)."
  WARNINGS=$((WARNINGS + 1))
fi

echo "================================================================="
if [ $ERRORS -eq 0 ]; then
  echo "✅ Auditoría completada sin errores críticos ($WARNINGS advertencias)."
else
  echo "❌ Auditoría finalizada con $ERRORS errores que requieren atención."
fi
echo "================================================================="
[ $ERRORS -eq 0 ]
