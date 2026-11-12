#!/usr/bin/env bash
# ==============================================================================
# Prueba de integración del ciclo completo de una tarea (AGENTS.md §3 y §4)
# Uso: bash tests/test-flow.sh
# Instala el sistema en un proyecto temporal con init-project.sh y recorre:
#   add -> start -> commit -> handoff -> (veto) close sin veredicto -> reject x3 ->
#   BLOCKED -> move -> start -> handoff -> close (revisor independiente) -> merge --no-ff
#
# Nota sobre flags de shell:
# Como ejecutor de suite no usa 'set -e': cada fallo incrementa FAIL y al concluir
# se sale con código 1 si FAIL > 0.
# ==============================================================================

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok()    { PASS=$((PASS + 1)); printf "  ✅ %s\n" "$1"; }
bad()   { FAIL=$((FAIL + 1)); printf "  ❌ %s\n" "$1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1  [$2]"; fi; }
section() { printf "\n▶ %s\n" "$1"; }

col() {
  awk -F'|' -v id="$1" -v c="$2" '/^\|/ { x=$2; gsub(/[ \t`]/,"",x); if (x==id) { v=$c; gsub(/[ \t`]/,"",v); print v; exit } }' GLOBAL_STATE.md
}
state() { col "$1" 5; }
iter()  { col "$1" 6; }

# Escribe el veredicto de QA con la misma estructura que la plantilla
write_review() {
  mkdir -p .agents/reviews
  cat > ".agents/reviews/qa_$1.md" <<REV
# Veredicto de QA: $1

- **Tarea**: \`$1\`
- **Revisor**: \`$2\`
- **Resultado**: \`$3\`
REV
}

DIR="$WORK/flujo"
mkdir -p "$DIR"
git -C "$DIR" init -q -b main
git -C "$DIR" config user.email test@example.com
git -C "$DIR" config user.name test
bash "$ROOT/.agents/scripts/init-project.sh" "Proyecto flujo" "$DIR" >/dev/null 2>&1
git -C "$DIR" add -A >/dev/null
git -C "$DIR" commit -qm "chore(TASK-000): instalar sistema" --no-verify
cd "$DIR" || exit 1
T=./.agents/scripts/task.sh

# ------------------------------------------------------------------------------
section "creación e inicio"
# La plantilla trae tareas de ejemplo: se usa el ID que devuelve add
ID=$($T add "Feature: endpoint de salud" "backend-agent" "GET /health responde 200" | grep -o 'TASK-[0-9]*' | head -1)
check "add devuelve el ID de la tarea" '[ -n "$ID" ]'
check "add crea la tarea en TODO" '[ "$(state $ID)" = "TODO" ]'
$T handoff $ID >/dev/null 2>&1
check "handoff desde TODO se rechaza" '[ "$(state $ID)" = "TODO" ]'
$T start $ID >/dev/null
check "start pasa a IN_PROGRESS" '[ "$(state $ID)" = "IN_PROGRESS" ]'
check "start crea y activa la rama feature/$ID-*" 'git branch --show-current | grep -q "^feature/$ID-"'
BRANCH=$(git branch --show-current)

# ------------------------------------------------------------------------------
section "entrega y veto de QA"
mkdir -p src && echo "export const health = () => 200;" > src/health.ts
git add -A >/dev/null
$T commit $ID "anadir endpoint de salud" feat >/dev/null 2>&1
check "commit convencional con $ID" 'git log -1 --format=%s | grep -q "^feat($ID): "'
HANDOFF_OUT=$($T handoff $ID backend-agent --verify "echo ok" 2>&1)
check "handoff avisa si el destino es el propio agente asignado" 'printf "%s" "$HANDOFF_OUT" | grep -q "quien REVISA"'
check "handoff pasa a IN_REVIEW_QA" '[ "$(state $ID)" = "IN_REVIEW_QA" ]'
check "handoff genera el JSON con los comandos de verificación" 'grep -q "echo ok" .agents/handoffs/handoff_$ID.json'
$T close $ID >/dev/null 2>&1
check "close sin archivo de veredicto se rechaza" '[ "$(state $ID)" = "IN_REVIEW_QA" ]'
write_review $ID backend-agent APROBADA
$T close $ID >/dev/null 2>&1
check "close con el autor como revisor se rechaza (cero auto-aprobación)" '[ "$(state $ID)" = "IN_REVIEW_QA" ]'

# ------------------------------------------------------------------------------
section "rechazos y límite de 3 iteraciones"
$T reject $ID "falta validar el metodo" >/dev/null 2>&1
check "reject 1/3 vuelve a IN_PROGRESS" '[ "$(state $ID)" = "IN_PROGRESS" ] && [ "$(iter $ID)" = "1/3" ]'
$T handoff $ID backend-agent >/dev/null 2>&1 && $T reject $ID "sigue fallando" >/dev/null 2>&1
check "reject 2/3" '[ "$(iter $ID)" = "2/3" ]'
$T handoff $ID backend-agent >/dev/null 2>&1 && $T reject $ID "no cumple el criterio" >/dev/null 2>&1
check "reject 3/3 bloquea la tarea (BLOCKED)" '[ "$(state $ID)" = "BLOCKED" ] && [ "$(iter $ID)" = "3/3" ]'
$T handoff $ID backend-agent >/dev/null 2>&1
check "una tarea BLOCKED no se puede entregar" '[ "$(state $ID)" = "BLOCKED" ]'
$T move $ID DONE >/dev/null 2>&1
check "move no permite saltar a DONE" '[ "$(state $ID)" = "BLOCKED" ]'
$T move $ID IN_PROGRESS >/dev/null 2>&1
check "tras decisión humana, move reinicia la tarea a 0/3" '[ "$(state $ID)" = "IN_PROGRESS" ] && [ "$(iter $ID)" = "0/3" ]'

# ------------------------------------------------------------------------------
section "aprobación y fusión a main"
echo "export const ready = true;" >> src/health.ts
git add -A >/dev/null
$T commit $ID "responder 200 solo con GET" feat >/dev/null 2>&1
$T handoff $ID backend-agent >/dev/null 2>&1
check "segundo handoff pasa a IN_REVIEW_QA" '[ "$(state $ID)" = "IN_REVIEW_QA" ]'
check "scan-secrets --branch limpio en la entrega" 'bash .agents/scripts/scan-secrets.sh --branch >/dev/null'
write_review $ID qa-security-agent APROBADA
$T close $ID >/dev/null 2>&1
check "tras haber sido rechazada, close exige lección o justificación" '[ "$(state $ID)" = "IN_REVIEW_QA" ]'
$T close $ID --no-lesson "Tarea de ejemplo del flujo" >/dev/null 2>&1
check "close con revisor independiente pasa a DONE" '[ "$(state $ID)" = "DONE" ]'
git add -A >/dev/null
git commit -qm "docs($ID): aprobar veredicto de QA y cierre a DONE" --no-verify
git checkout -q main
git merge --no-ff "$BRANCH" -m "chore($ID): fusionar rama" >/dev/null 2>&1
check "merge --no-ff crea un commit de fusión en main" '[ "$(git log -1 --format=%p | wc -w | tr -d " ")" = "2" ]'
git branch -d "$BRANCH" >/dev/null 2>&1
check "la rama de la tarea se elimina tras fusionar" '! git show-ref --verify --quiet "refs/heads/$BRANCH"'
check "el código llegó a main" '[ -f src/health.ts ]'
check "validate-state.sh sin errores tras el ciclo" 'bash .agents/scripts/validate-state.sh >/dev/null 2>&1'

# ------------------------------------------------------------------------------
cd "$ROOT" || exit 1
printf "\nResultado: %d OK, %d fallidas\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
