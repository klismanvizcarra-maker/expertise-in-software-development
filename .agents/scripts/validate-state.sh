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

# 1. Filas mal formadas
echo "-> Verificando formato del tablero..."
BAD=$(printf '%s\n' "$ROWS" | awk -F'|' 'NF == 3 && ($2 !~ /^(BACKLOG|TODO|IN_PROGRESS|IN_REVIEW_QA|BLOCKED|DONE)$/ || $3 !~ /^[0-3]\/3$/) { print "   " $0 }')
if [ -n "$BAD" ]; then
  echo "❌ Filas con estado o iteración inválidos (ID|ESTADO|ITERACIÓN):"
  echo "$BAD"
  ERRORS=$((ERRORS + 1))
else
  echo "   [OK] Todas las tareas tienen estado e iteración válidos."
fi

# 2. Regla de 3 iteraciones
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

# 3. Resumen
DONE_TASKS=$(printf '%s\n' "$ROWS" | awk -F'|' '$2 == "DONE" { n++ } END { print n+0 }')
echo "   [INFO] Tareas completadas (DONE): $DONE_TASKS"

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
