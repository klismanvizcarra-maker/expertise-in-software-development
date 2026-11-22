#!/usr/bin/env bash
# ==============================================================================
# auto-heal-ci.sh — Pipeline de Auto-Sanación y Diagnóstico de Fallos de CI
# SKILL MAESTRO v2.0
# Analiza trazas de error de CI (tests, linter, secretos, doctor) y genera
# tareas estructuradas de reparación (/bugfix) o aplica antídotos deterministas.
# Autor: Klisman Vizcarra
# ==============================================================================

set -euo pipefail
trap '' PIPE 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TASK_SH="$PROJECT_ROOT/.agents/scripts/task.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

if [ ! -t 1 ] || [ "${NO_COLOR:-0}" = "1" ]; then
  RED="" GREEN="" BLUE="" YELLOW="" BOLD="" NC=""
fi

die() {
  printf '%s\n' "${RED}❌ Error: $1${NC}" >&2
  exit 1
}

say() {
  printf '%b\n' "$1" 2>/dev/null || true
}

LOG_FILE=""
MODE="diagnose"
CREATE_TASK=0
AUTO_FIX=0

usage() {
  cat <<EOF
Pipeline de Auto-Sanación de CI (SKILL MAESTRO)
Uso: $0 [opciones] [--log <archivo_log>]
Analiza trazas de error de CI y genera diagnósticos estructurados o tareas de reparación.

Opciones:
  --log <ruta>           Archivo de log a inspeccionar (o lectura por stdin si no se especifica)
  --diagnose             Modo por defecto: analiza el log y emite reporte JSON y humano
  --create-task          Crea automáticamente una tarea Bug: en GLOBAL_STATE.md si hay fallo
  --auto-fix             Intenta aplicar correcciones deterministas automáticas conocidas
  -h, --help             Muestra esta ayuda y sale (exit 0)
EOF
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --log)
      shift
      [ -n "${1:-}" ] || die "Falta la ruta para --log."
      LOG_FILE="$1"
      ;;
    --log=*)
      LOG_FILE="${1#*=}"
      ;;
    --diagnose)
      MODE="diagnose"
      ;;
    --create-task)
      CREATE_TASK=1
      ;;
    --auto-fix)
      AUTO_FIX=1
      ;;
    -h|--help)
      usage
      ;;
    *)
      die "Argumento desconocido: '$1'."
      ;;
  esac
  shift
done

TMP_LOG=$(mktemp)
cleanup() {
  rm -f "$TMP_LOG"
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

if [ -n "$LOG_FILE" ]; then
  [ -f "$LOG_FILE" ] || die "El archivo de log '$LOG_FILE' no existe."
  cat "$LOG_FILE" > "$TMP_LOG"
else
  # Leer desde stdin si hay entrada disponible
  if [ ! -t 0 ]; then
    cat > "$TMP_LOG"
  else
    # Si no hay entrada por stdin ni archivo, usar buffer vacío
    : > "$TMP_LOG"
  fi
fi

# Diagnóstico inteligente con Python (100% biblioteca estándar)
DIAG_JSON=$(python3 -c '
import sys, re, json

log_path = sys.argv[1]
with open(log_path, "r", encoding="utf-8", errors="replace") as f:
    text = f.read()

detected_issues = []

# 1. Detección de fuga de secretos (scan-secrets.sh)
if "Secreto detectado" in text or "scan-secrets" in text and "FAIL" in text:
    files = re.findall(r"Archivo:\s*([^\s\n]+)", text)
    detected_issues.append({
        "type": "SECRET_LEAK",
        "severity": "CRITICAL",
        "category": "qa-security-agent",
        "title": "Fuga de secretos o tokens detectada en rama de CI",
        "files": list(set(files)) if files else ["desconocido"],
        "antidote": "Rotar credencial comprometida y eliminar rastro con scan-secrets.sh --branch"
    })

# 2. Antipatrón detectado por brain lint (LL-001, LL-007, etc.)
if "brain lint" in text and ("violación" in text or "violaciones" in text):
    m_ll = re.findall(r"(LL-[0-9]+)", text)
    ll_tag = m_ll[0] if m_ll else "detectado"
    detected_issues.append({
        "type": "BRAIN_ANTIPATTERN",
        "severity": "HIGH",
        "category": "devops-cloud-agent",
        "title": f"Violación de antipatrones aprendidos en CI: {ll_tag}",
        "files": [f.strip() for f in re.findall(r"==>\s*([^\s:\n]+)", text)],
        "antidote": "Aplicar antídoto documentado en .agents/brain/lessons_learned.md"
    })

# 3. Fallo de pruebas de scripts o unitarias
if "fallidas" in text or "FAIL" in text or "AssertionError" in text:
    fails = re.findall(r"❌\s*([^\n]+)", text)
    fail_summary = fails[0][:60] if fails else "Regresión de tests"
    detected_issues.append({
        "type": "TEST_FAILURE",
        "severity": "HIGH",
        "category": "qa-security-agent",
        "title": f"Fallo en suite de pruebas CI: {fail_summary}",
        "files": ["tests/test-scripts.sh"],
        "antidote": "Reproducir localmente con bash tests/test-scripts.sh y corregir regresión"
    })

# 4. Fallo de TypeScript o sintaxis
if "error TS" in text or "SyntaxError" in text:
    ts_files = re.findall(r"([^\s\n\(\)]+\.(?:ts|tsx|js|py)):", text)
    detected_issues.append({
        "type": "COMPILATION_ERROR",
        "severity": "HIGH",
        "category": "frontend-agent" if any(f.endswith((".ts", ".tsx")) for f in ts_files) else "backend-agent",
        "title": "Error de tipado TypeScript o sintaxis en build de CI",
        "files": list(set(ts_files))[:3] if ts_files else ["src/"],
        "antidote": "Ejecutar tsc --noEmit y resolver tipos incompatibles"
    })

# 5. Inconsistencias en GLOBAL_STATE.md
if "validate-state.sh" in text and "Error" in text:
    detected_issues.append({
        "type": "STATE_DRIFT",
        "severity": "MEDIUM",
        "category": "orchestrator-agent",
        "title": "Inconsistencia en el formato de GLOBAL_STATE.md",
        "files": ["GLOBAL_STATE.md"],
        "antidote": "Ejecutar .agents/scripts/validate-state.sh y corregir formato de tablero o historial"
    })

output = {
    "has_failures": len(detected_issues) > 0,
    "issues_count": len(detected_issues),
    "issues": detected_issues
}
print(json.dumps(output))
' "$TMP_LOG")

HAS_FAILURES=$(python3 -c "import sys, json; d=json.loads(sys.argv[1]); print(1 if d.get('has_failures') else 0)" "$DIAG_JSON")
ISSUES_COUNT=$(python3 -c "import sys, json; d=json.loads(sys.argv[1]); print(d.get('issues_count', 0))" "$DIAG_JSON")

say "${BLUE}${BOLD}=== Pipeline de Auto-Sanación CI (SKILL MAESTRO) ===${NC}"

if [ "$HAS_FAILURES" -eq 0 ]; then
  say "${GREEN}✅ No se detectaron fallos críticos en la traza inspeccionada.${NC}"
  say "$DIAG_JSON"
  exit 0
fi

say "${YELLOW}⚠️  Se detectaron ${ISSUES_COUNT} anomalía(s) en la ejecución de CI:${NC}"
python3 -c "
import sys, json
d = json.loads(sys.argv[1])
for idx, iss in enumerate(d['issues'], 1):
    print(f'  [{idx}] [{iss[\"severity\"]}] {iss[\"title\"]}')
    print(f'      Tipo: {iss[\"type\"]} | Especialista sugerido: {iss[\"category\"]}')
    print(f'      Archivos: {\", \".join(iss[\"files\"])}')
    print(f'      Antídoto: {iss[\"antidote\"]}')
" "$DIAG_JSON" 2>/dev/null || true

# Si se solicitó corrección automática
if [ "$AUTO_FIX" -eq 1 ]; then
  say ""
  say "${BLUE}-> Intentando auto-sanación determinista...${NC}"
  # 1. Sincronizar cerebro si hubo drift
  if [ -f "$TASK_SH" ]; then
    "$TASK_SH" brain sync >/dev/null 2>&1 || true
    say "   [OK] task.sh brain sync ejecutado."
  fi
fi

# Si se solicitó crear tarea en GLOBAL_STATE.md
if [ "$CREATE_TASK" -eq 1 ] && [ -f "$TASK_SH" ]; then
  say ""
  say "${BLUE}-> Creando tarea automática de corrección (/bugfix)...${NC}"
  FIRST_TITLE=$(python3 -c "import sys, json; d=json.loads(sys.argv[1]); print(d['issues'][0]['title'])" "$DIAG_JSON")
  FIRST_AGENT=$(python3 -c "import sys, json; d=json.loads(sys.argv[1]); print(d['issues'][0]['category'])" "$DIAG_JSON")
  FIRST_ANTIDOTE=$(python3 -c "import sys, json; d=json.loads(sys.argv[1]); print(d['issues'][0]['antidote'])" "$DIAG_JSON")
  
  TASK_DESC="Bug: Auto-heal CI: $FIRST_TITLE"
  TASK_CRIT="Investigar traza de fallo de CI; aplicar antídoto: $FIRST_ANTIDOTE; verificar con task.sh doctor en verde"
  
  # Verificar si ya existe una tarea idéntica para evitar duplicados
  if grep -qi "Auto-heal CI: $FIRST_TITLE" "$PROJECT_ROOT/GLOBAL_STATE.md" 2>/dev/null; then
    say "${YELLOW}ℹ️  Ya existe una tarea registrada para esta incidencia en GLOBAL_STATE.md.${NC}"
  else
    "$TASK_SH" add "$TASK_DESC" "$FIRST_AGENT" "$TASK_CRIT" >/dev/null
    NEW_TID=$(grep -E "Auto-heal CI:" "$PROJECT_ROOT/GLOBAL_STATE.md" | tail -1 | grep -oE "TASK-[0-9]+" || echo "TASK-NEW")
    say "${GREEN}✅ Tarea de auto-sanación registrada: $NEW_TID asignada a $FIRST_AGENT.${NC}"
    say "   Para iniciar reparación: ./task.sh start $NEW_TID"
  fi
fi

say "================================================================="
exit 0
