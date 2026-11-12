#!/usr/bin/env bash
# ==============================================================================
# Pruebas de regresión de los scripts del sistema (task.sh, hooks, init-project)
# Uso: bash tests/test-scripts.sh
# Cada prueba trabaja en un proyecto temporal instalado con init-project.sh.
#
# Nota sobre flags de shell:
# Como ejecutor de suite de pruebas, no utiliza 'set -e' para que las pruebas
# que fallan no aborten la ejecución completa del conjunto; cada fallo incrementa
# FAIL y al concluir se sale con código 1 si FAIL > 0.
# ==============================================================================

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf "  ✅ %s\n" "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf "  ❌ %s\n" "$1"; [ -n "$2" ] && printf "     %s\n" "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "$2"; fi; }
section() { printf "\n▶ %s\n" "$1"; }

# Columna N (5=estado, 6=iteración) de una tarea en el tablero
col() {
  awk -F'|' -v id="$1" -v c="$2" '/^\|/ { x=$2; gsub(/[ \t`]/,"",x); if (x==id) { v=$c; gsub(/[ \t`]/,"",v); print v; exit } }' GLOBAL_STATE.md
}

new_project() {
  local dir="$WORK/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  bash "$ROOT/.agents/scripts/init-project.sh" "Proyecto $1" "$dir" >/dev/null 2>&1
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -qm "chore(TASK-000): instalar sistema" --no-verify
  cd "$dir" || exit 1
}

T=./.agents/scripts/task.sh

# ------------------------------------------------------------------------------
section "init-project.sh"
new_project init
check "enlace .claude/skills -> .agents/skills" '[ -L .claude/skills ] && [ -f .claude/skills/qa-security-agent/SKILL.md ]'
check "CLAUDE.md importa AGENTS.md" 'grep -q "^@AGENTS.md" CLAUDE.md'
check ".mcp.json y plugin MCP de Antigravity instalados" '[ -f .mcp.json ] && [ -f .agents/plugins/maestro-mcp/mcp_config.json ]'
check "existe .agents/VERSION" '[ -f .agents/VERSION ] && [ -n "$(cat .agents/VERSION)" ]'
check "cerebro sin lecciones de ejemplo" '! grep -qE "^\| *\`?LL-" BRAIN.md .agents/brain/lessons_learned.md'
check "deuda técnica sin filas de ejemplo" '! grep -qE "^\| *\`?TD-" .agents/brain/tech_debt.md'
$T learn "Leccion real" backend "causa" "solucion" >/dev/null
bash "$ROOT/.agents/scripts/init-project.sh" "Proyecto init" . >/dev/null 2>&1
check "reinstalar conserva lecciones del proyecto" 'grep -q "Leccion real" .agents/brain/lessons_learned.md && grep -q "Leccion real" BRAIN.md'

mkdir -p .agents/skills/dummy-retirada
bash "$ROOT/.agents/scripts/init-project.sh" --update . >/dev/null 2>&1
check "init-project --update sincroniza y elimina skills retiradas" '! [ -d .agents/skills/dummy-retirada ] && grep -q "Leccion real" BRAIN.md'

mkdir -p "$WORK/nextjs-app" && git -C "$WORK/nextjs-app" init -q
bash "$ROOT/.agents/scripts/init-project.sh" "Mi Next App" "$WORK/nextjs-app" --stack nextjs >/dev/null 2>&1
check "init-project con --stack nextjs pre-configura GLOBAL_STATE.md" 'grep -q "stack-nextjs-tailwind-prisma" "$WORK/nextjs-app/GLOBAL_STATE.md" && grep -q "Prisma" "$WORK/nextjs-app/GLOBAL_STATE.md"'

mkdir -p "$WORK/angular-app" && git -C "$WORK/angular-app" init -q
bash "$ROOT/.agents/scripts/init-project.sh" "Mi Angular App" "$WORK/angular-app" --stack angular >/dev/null 2>&1
check "init-project con --stack angular pre-configura GLOBAL_STATE.md" 'grep -q "stack-angular-express-postgres" "$WORK/angular-app/GLOBAL_STATE.md" && grep -q "Drizzle" "$WORK/angular-app/GLOBAL_STATE.md"'

bash "$ROOT/.agents/scripts/init-project.sh" "Mi API" "$WORK/fastapi-app" --stack fastapi >/dev/null 2>&1
check "init-project con --stack fastapi pre-configura GLOBAL_STATE.md" 'grep -q "stack-fastapi-postgres" "$WORK/fastapi-app/GLOBAL_STATE.md" && grep -q "SQLAlchemy" "$WORK/fastapi-app/GLOBAL_STATE.md"'
for st in nextjs angular fastapi; do
  [ -d "$WORK/$st-app" ] || bash "$ROOT/.agents/scripts/init-project.sh" "App $st" "$WORK/$st-app" --stack $st >/dev/null 2>&1
  check "--stack $st no deja placeholders ni líneas corruptas en GLOBAL_STATE.md" '! grep -qE "\[Breve descripci|\[Plataforma|Elección del stack base" "$WORK/$st-app/GLOBAL_STATE.md" && [ "$(grep -c "Infraestructura" "$WORK/$st-app/GLOBAL_STATE.md")" -eq 1 ] && grep -q "^- \*\*Descripción\*\*: \`[^\`]*\`$" "$WORK/$st-app/GLOBAL_STATE.md"'
done
check "--stack fastapi instala la skill del stack" '[ -f "$WORK/fastapi-app/.agents/skills/stack-fastapi-postgres/SKILL.md" ]'
check "--stack con valor desconocido sale con exit 1" '! bash "$ROOT/.agents/scripts/init-project.sh" "App" . --stack desconocido >/dev/null 2>&1'
check "--stack sin valor ni --stack= vacío fallan con exit 1" '! bash "$ROOT/.agents/scripts/init-project.sh" "App" "$WORK/stack-empty" --stack >/dev/null 2>&1 && ! bash "$ROOT/.agents/scripts/init-project.sh" "App" "$WORK/stack-empty" --stack= >/dev/null 2>&1'
check "strip_examples conserva permisos legibles (no 0600 de mktemp)" 'python3 -c "import os,stat; m=stat.S_IMODE(os.stat(\"BRAIN.md\").st_mode); assert (m & 0o044) == 0o044, oct(m)"'

mkdir -p "$WORK/escaped-app" && git -C "$WORK/escaped-app" init -q
bash "$ROOT/.agents/scripts/init-project.sh" "I&D / Innovation & SaaS" "$WORK/escaped-app" >/dev/null 2>&1
check "nombres de proyecto con & o / se sustituyen literalmente" 'grep -q "I&D / Innovation & SaaS" "$WORK/escaped-app/GLOBAL_STATE.md" && grep -q "I&D / Innovation & SaaS" "$WORK/escaped-app/README.md"'

mkdir -p "$WORK/ci-app" && git -C "$WORK/ci-app" init -q
bash "$ROOT/.agents/scripts/init-project.sh" "Mi App CI" "$WORK/ci-app" --ci >/dev/null 2>&1
check "init-project --ci instala .github/workflows/audit.yml" '[ -f "$WORK/ci-app/.github/workflows/audit.yml" ] && grep -q "Audit" "$WORK/ci-app/.github/workflows/audit.yml"'
check "ci_workflow_template soporta Node 24 (lint, typecheck, test, build)" 'grep -q "package.json" "$WORK/ci-app/.github/workflows/audit.yml" && grep -q "node-version: 24" "$WORK/ci-app/.github/workflows/audit.yml" && grep -q "npm run typecheck --if-present" "$WORK/ci-app/.github/workflows/audit.yml"'
check "ci_workflow_template soporta Python 3.12 (pyproject/requirements, ruff, pytest)" 'grep -q "pyproject.toml" "$WORK/ci-app/.github/workflows/audit.yml" && grep -q "requirements.txt" "$WORK/ci-app/.github/workflows/audit.yml" && grep -q "python-version: .3\.12." "$WORK/ci-app/.github/workflows/audit.yml" && grep -q "ruff check" "$WORK/ci-app/.github/workflows/audit.yml" && grep -q "pytest" "$WORK/ci-app/.github/workflows/audit.yml"'
check "ci_workflow_template fija todas las GitHub Actions a SHA de 40 hex y sin tabuladores" 'python3 -c "
import re, sys
txt = open(sys.argv[1], encoding=\"utf-8\").read()
assert \"\\t\" not in txt, \"YAML contiene tabuladores\"
uses = re.findall(r\"uses:[ \t]+(\\S+)\", txt)
assert len(uses) >= 4, uses
for u in uses:
    assert re.search(r\"@[0-9a-f]{40}$\", u), f\"Action sin SHA inmutable: {u}\"
" "$WORK/ci-app/.github/workflows/audit.yml"'
check "QUICKSTART y stack_template documentan stacks adicionales" 'grep -q "stack-<nombre>" "$ROOT/QUICKSTART.md" && grep -q "stack-<nombre>" "$ROOT/.agents/templates/stack_template.md"'
echo "# personalizado" > "$WORK/ci-app/.github/workflows/audit.yml"
bash "$ROOT/.agents/scripts/init-project.sh" "Mi App CI" "$WORK/ci-app" --ci >/dev/null 2>&1
check "init-project --ci no sobrescribe workflow existente" 'grep -q "# personalizado" "$WORK/ci-app/.github/workflows/audit.yml"'

check "tareas de ejemplo de la plantilla usan nombres de skill" 'grep -q "orchestrator-agent" "$ROOT/.agents/templates/GLOBAL_STATE_TEMPLATE.md" && grep -q "backend-agent" "$ROOT/.agents/templates/GLOBAL_STATE_TEMPLATE.md"'

# ------------------------------------------------------------------------------
section "task.sh add / move / list / metrics"
new_project board
$T add "Login con | barra y TODO DONE" "backend-agent" "Tests en verde" >/dev/null
check "add inserta la fila en el tablero" '[ "$(col TASK-003 5)" = TODO ] && [ "$(col TASK-003 6)" = 0/3 ]'
check "add sanea la barra vertical" 'grep -q "Login con / barra" GLOBAL_STATE.md'
check "add no escribe en la tabla de historial" '[ "$(sed -n "/Registro Cronológico/,\$p" GLOBAL_STATE.md | grep -c TASK-003)" = 0 ]'
check "add sin criterios falla" '! $T add "Sin criterios" backend-agent >/dev/null 2>&1'
$T move TASK-003 BACKLOG >/dev/null
check "move cambia solo la columna de estado" '[ "$(col TASK-003 5)" = BACKLOG ] && grep -q "barra y TODO DONE" GLOBAL_STATE.md'
$T move TASK-003 TODO >/dev/null
check "move de BACKLOG a TODO permitido" '[ "$(col TASK-003 5)" = TODO ]'
check "replanificar queda en el historial" 'grep -q "Replanificada BACKLOG -> TODO" GLOBAL_STATE.md'
$T move TASK-003 TODO >/dev/null
check "move al mismo estado no ensucia el historial" '[ "$(grep -c "Replanificada .* -> TODO" GLOBAL_STATE.md)" = 1 ]'
check "move a DONE falla con exit 1 (no salta el veto de QA)" '$T move TASK-003 DONE >/dev/null 2>&1; [ $? -eq 1 ] && [ "$(col TASK-003 5)" = TODO ]'
check "move a IN_REVIEW_QA falla (se entrega con handoff)" '! $T move TASK-003 IN_REVIEW_QA >/dev/null 2>&1 && [ "$(col TASK-003 5)" = TODO ]'
check "move a BLOCKED falla (solo el tercer reject bloquea)" '! $T move TASK-003 BLOCKED >/dev/null 2>&1 && [ "$(col TASK-003 5)" = TODO ]'
check "move a IN_PROGRESS fuera de BLOCKED falla (se usa start)" '! $T move TASK-003 IN_PROGRESS >/dev/null 2>&1 && [ "$(col TASK-003 5)" = TODO ]'
check "el error de move a DONE indica task.sh close" '$T move TASK-003 DONE 2>&1 | grep -q "task.sh close"'
$T add "Tarea bloqueada" "backend-agent" "x" >/dev/null
perl -pi -e 's/^(\| `TASK-004` .*)\| `TODO` \| `0\/3` \|/$1| `BLOCKED` | `3\/3` |/' GLOBAL_STATE.md
$T move TASK-004 IN_PROGRESS >/dev/null
check "move de BLOCKED a IN_PROGRESS permitido y reinicia a 0/3" '[ "$(col TASK-004 5)" = IN_PROGRESS ] && [ "$(col TASK-004 6)" = 0/3 ]'
check "move con estado inválido falla" '! $T move TASK-003 HECHO >/dev/null 2>&1'
check "move de tarea inexistente falla" '! $T move TASK-999 DONE >/dev/null 2>&1'
check "metrics no cuenta 'DONE' de la descripción" '$T metrics | grep -q "DONE:.* 0"'
check "list muestra solo filas del tablero" '[ "$($T list | grep -c "^|")" = 4 ]'

new_project concurrency
for i in $(seq 1 10); do
  $T add "Tarea concurrente $i" "devops-cloud-agent" "Criterio $i" >/dev/null 2>&1 &
done
wait
check "concurrencia: 10 add en paralelo dejan 10 tareas con IDs únicos" '[ "$(awk -F"|" "/^\|/ { id=\$2; gsub(/[ \t\`]/,\"\",id); if (id ~ /^TASK-[0-9]+$/) print id }" GLOBAL_STATE.md | wc -l | tr -d " ")" = 12 ] && [ "$(awk -F"|" "/^\|/ { id=\$2; gsub(/[ \t\`]/,\"\",id); if (id ~ /^TASK-[0-9]+$/) print id }" GLOBAL_STATE.md | sort | uniq -d | wc -l | tr -d " ")" = 0 ]'
check "concurrencia: formato de GLOBAL_STATE.md íntegro tras add paralelos" 'bash "$ROOT/.agents/scripts/validate-state.sh" >/dev/null'

# ------------------------------------------------------------------------------
section "task.sh ciclo de vida: start / handoff / reject / close"
new_project cycle
$T add "Endpoint \"login\" v1" "backend-agent" "401 sin token" >/dev/null
check "handoff desde TODO falla" '! $T handoff TASK-003 >/dev/null 2>&1'
check "start de tarea inexistente falla" '! $T start TASK-999 >/dev/null 2>&1'
$T start task-003 >/dev/null
check "start acepta minúsculas y pasa a IN_PROGRESS" '[ "$(col TASK-003 5)" = IN_PROGRESS ]'
check "start crea la rama feature/TASK-003-..." '[ "$(git branch --show-current)" = "feature/TASK-003-endpoint-login-v1" ]'
$T add "Bug: Login da 500" "backend-agent" "test de regresión" >/dev/null
$T add "Refactor: servicio de pedidos" "backend-agent" "tests en verde" >/dev/null
$T start TASK-004 >/dev/null
check "start usa fix/ para tareas 'Bug:'" '[ "$(git branch --show-current)" = "fix/TASK-004-login-da-500" ]'
$T start TASK-005 >/dev/null
check "start usa refactor/ para tareas 'Refactor:'" '[ "$(git branch --show-current)" = "refactor/TASK-005-servicio-de-pedidos" ]'
$T add "Auditoría de diagnóstico" "orchestrator-agent" "criterios" >/dev/null
$T start TASK-006 >/dev/null
check "start normaliza tildes en el nombre de rama" '[ "$(git branch --show-current)" = "feature/TASK-006-auditoria-de-diagnostico" ]'
git checkout -q "feature/TASK-003-endpoint-login-v1"
echo "export const a = 1" > a.ts
$T handoff TASK-003 >/dev/null
J=.agents/handoffs/handoff_TASK-003.json
check "handoff pasa a IN_REVIEW_QA" '[ "$(col TASK-003 5)" = IN_REVIEW_QA ]'
check "handoff genera JSON válido con comillas escapadas" 'python3 -c "import json,sys; d=json.load(open(\"$J\")); sys.exit(0 if d[\"summary\"]==\"Endpoint \\\"login\\\" v1\" else 1)"'
check "handoff registra iteración 1 y el archivo entregado" 'python3 -c "import json,sys; d=json.load(open(\"$J\")); sys.exit(0 if d[\"iteration\"]==1 and any(x[\"path\"]==\"a.ts\" for x in d[\"deliverables\"]) else 1)"'
check "handoff añade fila en historial de GLOBAL_STATE.md" 'grep -q "| \`TASK-003\` |.*Comandos: \`./.agents/scripts/validate-state.sh\`" GLOBAL_STATE.md'
check "reject sin motivo falla" '! $T reject TASK-003 >/dev/null 2>&1'
check "reject de tarea inexistente falla" '! $T reject TASK-999 "x" >/dev/null 2>&1'
$T reject TASK-003 "falta 401" >/dev/null
check "reject 1/3 devuelve a IN_PROGRESS" '[ "$(col TASK-003 5)" = IN_PROGRESS ] && [ "$(col TASK-003 6)" = 1/3 ]'
check "reject queda en el historial" 'grep -q "Rechazo 1/3: falta 401" GLOBAL_STATE.md'
check "reject fuera de IN_REVIEW_QA falla" '! $T reject TASK-003 "x" >/dev/null 2>&1'
$T start TASK-003 >/dev/null; $T handoff TASK-003 >/dev/null
check "segundo handoff registra iteración 2" 'grep -q "\"iteration\": 2" $J'
$T reject TASK-003 "x" >/dev/null; $T start TASK-003 >/dev/null; $T handoff TASK-003 >/dev/null; $T reject TASK-003 "y" >/dev/null
check "tercer rechazo -> BLOCKED 3/3" '[ "$(col TASK-003 5)" = BLOCKED ] && [ "$(col TASK-003 6)" = 3/3 ]'
check "start sobre BLOCKED falla" '! $T start TASK-003 >/dev/null 2>&1'
check "validate-state detecta el deadlock" './.agents/scripts/validate-state.sh | grep -q "DEADLOCK"'
check "move de BLOCKED a DONE falla" '! $T move TASK-003 DONE >/dev/null 2>&1 && [ "$(col TASK-003 5)" = BLOCKED ]'
check "move de BLOCKED a IN_REVIEW_QA falla" '! $T move TASK-003 IN_REVIEW_QA >/dev/null 2>&1 && [ "$(col TASK-003 5)" = BLOCKED ]'
$T move TASK-003 TODO >/dev/null
check "desbloquear reinicia el contador a 0/3" '[ "$(col TASK-003 5)" = TODO ] && [ "$(col TASK-003 6)" = 0/3 ]'
check "close fuera de IN_REVIEW_QA falla" '! $T close TASK-003 >/dev/null 2>&1'
$T start TASK-003 >/dev/null
check "move de IN_PROGRESS a DONE falla" '! $T move TASK-003 DONE >/dev/null 2>&1 && [ "$(col TASK-003 5)" = IN_PROGRESS ]'
$T handoff TASK-003 >/dev/null
check "move de IN_REVIEW_QA a DONE falla (solo close)" '! $T move TASK-003 DONE >/dev/null 2>&1 && [ "$(col TASK-003 5)" = IN_REVIEW_QA ]'
check "close sin veredicto falla" '! $T close TASK-003 >/dev/null 2>&1'
mkdir -p .agents/reviews
echo "- **Revisor**: backend-agent" > .agents/reviews/qa_TASK-003.md
check "close con autor como revisor falla" '! $T close TASK-003 >/dev/null 2>&1'
echo "- **Revisor**: qa-security-agent" > .agents/reviews/qa_TASK-003.md
check "close de una tarea que llegó a BLOCKED sigue exigiendo lección tras move" '! $T close TASK-003 >/dev/null 2>&1 && [ "$(col TASK-003 5)" = IN_REVIEW_QA ]'
CLOSE_OUT=$($T close TASK-003 --no-lesson "Tarea de prueba del ciclo de vida")
check "close tras revisión con revisor independiente -> DONE" '[ "$(col TASK-003 5)" = DONE ]'
check "close muestra comando de fusión a main" 'echo "$CLOSE_OUT" | grep -q "git merge --no-ff"'

$T add "Tarea con verificación" "backend-agent" "criterios" >/dev/null
$T start TASK-007 >/dev/null
$T handoff TASK-007 qa-security-agent --verify "npm test" --verify "npm run build" --summary "Entrega con pruebas" >/dev/null
J7=.agents/handoffs/handoff_TASK-007.json
check "handoff con --verify guarda comandos en JSON" 'python3 -c "import json,sys; d=json.load(open(\"$J7\")); sys.exit(0 if d[\"verification_commands\"]==[\"npm test\", \"npm run build\"] else 1)"'
check "handoff con --verify y --summary registra fila en historial de GLOBAL_STATE.md" 'grep -q "Entrega con pruebas. Comandos: \`npm test\`, \`npm run build\`" GLOBAL_STATE.md'

TODAY_STR=$(date +"%Y-%m-%d")
sed -i.bak 's/- \*\*Última Actualización\*\*: `[^`]*`/- **Última Actualización**: `2000-01-01`/' GLOBAL_STATE.md && rm -f GLOBAL_STATE.md.bak
$T add "No saltar a TASK-999 desde descripcion" "backend-agent" "ver TASK-888" >/dev/null
check "next_id ignora TASK-999 en texto y add actualiza Última Actualización" 'grep -q "| \`TASK-008\` |" GLOBAL_STATE.md && ! grep -q "| \`TASK-1000\` |" GLOBAL_STATE.md && grep -q "\*\*Última Actualización\*\*: \`$TODAY_STR\`" GLOBAL_STATE.md'
git checkout -q main 2>/dev/null
$T start TASK-008 >/dev/null
printf 'x = 1\n' > 'configuración.ts' && printf 'y = 2\n' > 'archivo "raro".ts'
$T handoff TASK-008 --summary "Rechazo 1/3 simulado en summary de entrega" >/dev/null
check "handoff registra rutas no ASCII y comillas en JSON válido" 'python3 -c "import json; d=json.load(open(\".agents/handoffs/handoff_TASK-008.json\")); paths={x[\"path\"] for x in d[\"deliverables\"]}; assert \"configuración.ts\" in paths and \"archivo \\\"raro\\\".ts\" in paths"'
rm -f 'configuración.ts' 'archivo "raro".ts'
echo "- **Revisor**: qa-security-agent" > .agents/reviews/qa_TASK-008.md
CLOSE_8=$($T close TASK-008 2>&1)
check "close ignora Rechazo 1/3 si el emisor no es qa-security-agent (TD-004)" 'grep -q "backend-agent.*TASK-008.*Rechazo 1/3 simulado" GLOBAL_STATE.md && printf "%s" "$CLOSE_8" | grep -q "TASK-008 aprobada y cerrada"'
git checkout -q main 2>/dev/null
$T start TASK-001 >/dev/null && $T handoff TASK-001 >/dev/null
echo "- **Revisor**: qa-security-agent" > .agents/reviews/qa_TASK-001.md
CUR_T1=$(git branch --show-current)
git checkout -q main 2>/dev/null && git branch -M "$CUR_T1" feature/TASK-0010-colision
CLOSE_1=$($T close TASK-001 2>&1)
check "close no confunde TASK-001 con la rama de TASK-0010" '! printf "%s" "$CLOSE_1" | grep -q "TASK-0010"'
git branch -D feature/TASK-0010-colision >/dev/null 2>&1 || true

# ------------------------------------------------------------------------------
section "task.sh learn / debt"
new_project brain
$T learn "Problema A" backend "Causa A" "Solucion A" >/dev/null
$T learn "Problema B" database >/dev/null
check "learn numera LL-001 y LL-002 sin duplicados" '[ "$(grep -c "LL-001" BRAIN.md)" = 1 ] && grep -q "LL-002" BRAIN.md && grep -q "LL-002" .agents/brain/lessons_learned.md'
check "learn: 8 columnas (con Ámbito y Estado) e idénticas en BRAIN.md y lessons_learned.md" '[ "$(grep "Problema A" BRAIN.md | awk -F"|" "{print NF-2}")" = 8 ] && [ "$(grep "Problema A" BRAIN.md)" = "$(grep "Problema A" .agents/brain/lessons_learned.md)" ]'
$T debt "Paginacion en memoria" TASK-001 "Paginar en SQL" baja >/dev/null
check "debt registra TD-001 con prioridad normalizada y la refleja en BRAIN.md" 'grep -q "TD-001.*\`BAJA\`" .agents/brain/tech_debt.md && grep -q "TD-001" BRAIN.md'
check "debt con prioridad inválida falla" '! $T debt "x" TASK-001 "y" URGENTE >/dev/null 2>&1'
$T learn "Fallo de paginacion en listado de usuarios" backend "c" "s" >/dev/null 2>&1 || true
check "learn rechaza una lección casi idéntica a una activa" '! $T learn "Fallo de paginacion en el listado de usuarios" backend "c2" "s2" >/dev/null 2>&1'
$T learn "Error en login" backend "c" "s" >/dev/null
check "learn rechaza una lección idéntica aunque sea corta" '! $T learn "Error en login" backend "c" "s" >/dev/null 2>&1'
$T learn "Paginación incorrecta en migración automática" database "c" "s" >/dev/null
check "learn detecta duplicados con otras mayúsculas (locale C)" '! LC_ALL=C $T learn "PAGINACIÓN INCORRECTA EN MIGRACIÓN AUTOMÁTICA" database "c" "s" >/dev/null 2>&1'
check "learn detecta duplicados escritos sin tildes" '! $T learn "Paginacion incorrecta en migracion automatica" database "c" "s" >/dev/null 2>&1'
check "learn --force registra aunque exista una parecida" '$T learn "Fallo de paginacion en el listado de usuarios" backend "c2" "s2" --force >/dev/null && [ "$(grep -c "Fallo de paginacion" BRAIN.md)" = 2 ]'
check "learn acepta una lección distinta sin --force" '$T learn "Timeout en webhook de pagos" backend "c" "s" >/dev/null'
LL_RET=$(grep "Timeout en webhook" BRAIN.md | grep -oE "LL-[0-9]+" | head -1)
$T lesson-retire "$LL_RET" >/dev/null
check "lesson-retire marca OBSOLETA en BRAIN.md y en lessons_learned.md" 'grep "$LL_RET" BRAIN.md | grep -q "OBSOLETA" && ! grep "$LL_RET" BRAIN.md | grep -q "ACTIVO" && grep "$LL_RET" .agents/brain/lessons_learned.md | grep -q "OBSOLETA"'
check "lesson-retire conserva las 8 columnas de la fila" '[ "$(grep "$LL_RET" BRAIN.md | awk -F"|" "{print NF-2}")" = 8 ]'
check "una lección OBSOLETA ya no bloquea registrar otra parecida" '$T learn "Timeout en webhook de pagos" backend "c" "s" >/dev/null'
check "lesson-retire con ID inexistente falla" '! $T lesson-retire LL-999 >/dev/null 2>&1'
$T debt "Segunda deuda mencionando TD-099 en texto" TASK-001 "Accion" media >/dev/null
check "next_id TD ignora TD-099 en el texto y debt sincroniza BRAIN.md" 'grep -q "^| \`TD-002\`" .agents/brain/tech_debt.md && grep -q "TD-002" BRAIN.md'
$T debt-resolve TD-001 >/dev/null
check "debt-resolve marca SALDADA en tech_debt.md y la retira de BRAIN.md" 'grep "TD-001" .agents/brain/tech_debt.md | grep -q "SALDADA" && ! grep -q "TD-001" BRAIN.md && grep -q "TD-002" BRAIN.md && ! grep "TD-002" .agents/brain/tech_debt.md | grep -q "SALDADA"'
check "debt-resolve conserva las columnas de la fila" '[ "$(grep "TD-001" .agents/brain/tech_debt.md | awk -F"|" "{print NF}")" = "$(grep "TD-002" .agents/brain/tech_debt.md | awk -F"|" "{print NF}")" ]'
check "debt-resolve dos veces sobre la misma deuda falla" '! $T debt-resolve TD-001 >/dev/null 2>&1'
check "debt-resolve con ID inexistente falla" '! $T debt-resolve TD-999 >/dev/null 2>&1'
$T debt-resolve TD-002 >/dev/null
check "tras saldar la última deuda el siguiente ID no se reutiliza" '$T debt "Tercera" TASK-001 "x" baja >/dev/null && grep -q "TD-003" .agents/brain/tech_debt.md && [ "$(grep -c "TD-002" .agents/brain/tech_debt.md)" = 1 ]'
$T add "Tarea con cerebro" "backend-agent" "criterio" >/dev/null
START_OUT=$($T start "$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)" 2>&1)
check "start recuerda las lecciones activas de BRAIN.md" 'printf "%s" "$START_OUT" | grep -q "Lecciones activas" && printf "%s" "$START_OUT" | grep -q "Problema A"'
check "start no lista lecciones OBSOLETAS" '! printf "%s" "$START_OUT" | grep -q "$LL_RET "'
for n in 1 2 3 4 5 6; do $T learn "Incidente frontend numero $n con render distinto $n$n" frontend "c" "s" --force >/dev/null; done
$T add "Otra tarea de backend" "backend-agent" "criterio" >/dev/null
START_OUT=$($T start "$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)" 2>&1)
check "start prioriza las lecciones de la categoría del agente asignado" 'printf "%s" "$START_OUT" | grep -q "\[BACKEND\] Problema A" && printf "%s" "$START_OUT" | grep -q "\[BACKEND\] Error en login"'
TEMPLATE_SUM=$(cksum < .agents/templates/BRAIN_TEMPLATE.md)
mv BRAIN.md "$WORK/brain.bak"
check "learn sin BRAIN.md falla sin tocar plantillas" '! $T learn "x" >/dev/null 2>&1 && [ "$(cksum < .agents/templates/BRAIN_TEMPLATE.md)" = "$TEMPLATE_SUM" ]'
mv "$WORK/brain.bak" BRAIN.md

# ------------------------------------------------------------------------------
section "cerebro: fuente única, ámbito y recuperación dirigida (task.sh brain)"
new_project cerebro
$T learn "Consulta lenta en listado de pedidos" database "Falta indice en la FK" "Crear indice en cada FK" --paths "server/db/*.sql,migrations/*" >/dev/null
$T learn "Token expirado devuelve 500" backend "No se captura el error de JWT" "Middleware que traduce a 401" >/dev/null
check "learn --paths guarda el ámbito y sin --paths queda general (*)" 'grep "Consulta lenta" .agents/brain/lessons_learned.md | grep -qF "server/db/*.sql,migrations/*" && grep "Token expirado" .agents/brain/lessons_learned.md | grep -qF "| \`*\` | \`ACTIVO\` |"'
check "la tabla de BRAIN.md es copia exacta de lessons_learned.md" '[ "$(grep "^| \`LL-" BRAIN.md)" = "$(grep "^| \`LL-" .agents/brain/lessons_learned.md)" ]'
printf '%s\n' "| \`LL-050\` | 2026-01-01 | \`[QA]\` | Editada a mano en la fuente | causa | solucion | \`*\` | \`ACTIVO\` |" > "$WORK/fila.txt"
awk -v f="$WORK/fila.txt" '{ print } /^\| `LL-002`/ { while ((getline l < f) > 0) print l }' .agents/brain/lessons_learned.md > "$WORK/ll.tmp" && cat "$WORK/ll.tmp" > .agents/brain/lessons_learned.md
$T brain sync >/dev/null
check "brain sync lleva a BRAIN.md una fila añadida a mano en la fuente" 'grep -q "LL-050" BRAIN.md && grep -q "## 3" BRAIN.md'
check "brain sync es idempotente" 'cp BRAIN.md "$WORK/b1" && $T brain sync >/dev/null && cmp -s BRAIN.md "$WORK/b1"'
check "tras una fila manual el siguiente ID no la pisa" '$T learn "Otra leccion cualquiera distinta" qa "c" "s" >/dev/null && grep -q "LL-051" BRAIN.md'
$T brain scope LL-002 "server/auth/*.ts" >/dev/null
check "brain scope cambia el ámbito en las dos tablas" 'grep "LL-002" BRAIN.md | grep -qF "server/auth/*.ts" && grep "LL-002" .agents/brain/lessons_learned.md | grep -qF "server/auth/*.ts"'
check "brain scope con ID inexistente falla" '! $T brain scope LL-999 "x/*" >/dev/null 2>&1'
check "brain search encuentra sin distinguir tildes ni mayúsculas" '$T brain search "ÍNDICE" pedidos | grep -q "LL-001"'
check "brain search exige todos los términos" '! $T brain search indice inexistentexyz | grep -q "LL-001"'
$T debt "Paginacion en memoria en pedidos" TASK-001 "Paginar en SQL" alta >/dev/null
check "brain search incluye la deuda técnica" '$T brain search paginacion | grep -q "DEUDA.*TD-001"'
$T add "Optimizar el listado de pedidos con consulta lenta" "frontend-agent" "El listado carga en menos de 1 s" >/dev/null
BT=$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)
check "brain for relaciona por palabras de la tarea" '$T brain for "$BT" | grep -q "LL-001.*Consulta lenta"'
check "brain for no lista lecciones sin relación" '! $T brain for "$BT" | grep -q "LL-051"'
check "brain for relaciona por ruta con el ámbito de la lección" '$T brain for "$BT" server/auth/login.ts | grep -A2 "LL-002" | grep -q "ámbito server/auth/\*.ts"'
check "brain for acepta rutas absolutas" '$T brain for "$BT" "$PWD/migrations/0001_init.sql" | grep -A2 "LL-001" | grep -q "ámbito migrations/\*"'
check "brain for muestra la deuda de prioridad ALTA" '$T brain for "$BT" | grep -q "TD-001"'
$T add "Endpoint de salud" "backend-agent" "Responde 200" >/dev/null
check "brain for relaciona por categoría del agente" '$T brain for "$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)" | grep -A2 "LL-002" | grep -q "categoría BACKEND"'
$T lesson-retire LL-001 >/dev/null
check "una lección OBSOLETA no aparece en brain for pero sí en brain search" '! $T brain for "$BT" | grep -q "LL-001" && $T brain search pedidos | grep -q "LL-001.*OBSOLETA"'
START_OUT=$($T start "$BT" 2>&1)
check "start muestra las lecciones relevantes con su motivo" 'printf "%s" "$START_OUT" | grep -q "brain for $BT"'
git checkout -q main 2>/dev/null
# Migración desde el esquema antiguo (BRAIN.md con 7 columnas, lessons_learned.md con 6)
new_project cerebro-antiguo
python3 - <<'PYEOF'
import re
b = open('BRAIN.md').read()
b = b.replace('| ID | Fecha | Categoría | Problema Encontrado | Causa Raíz | Solución Aplicada (Antídoto) | Ámbito | Estado |\n| :---: | :---: | :---: | :--- | :--- | :--- | :--- | :---: |',
              '| ID | Fecha | Categoría | Problema Detectado | Causa Raíz | Solución Definitiva (Antídoto) | Estado |\n| :---: | :---: | :---: | :--- | :--- | :--- | :---: |\n| `LL-001` | 2026-01-01 | `[BACKEND]` | Vieja activa | c | s | `ACTIVO` |\n| `LL-002` | 2026-01-02 | `[BACKEND]` | Vieja retirada | c | s | `OBSOLETA` |\n| `LL-003` | 2026-01-03 | `[QA]` | Solo en brain | c | s | `ACTIVO` |')
open('BRAIN.md', 'w').write(b)
l = open('.agents/brain/lessons_learned.md').read()
l = l.replace('| ID | Fecha | Categoría | Problema Encontrado | Causa Raíz | Solución Aplicada (Antídoto) | Ámbito | Estado |\n| :---: | :---: | :---: | :--- | :--- | :--- | :--- | :---: |',
              '| ID | Fecha | Categoría | Problema Encontrado | Causa Raíz | Solución Aplicada (Antídoto) |\n| :---: | :---: | :---: | :--- | :--- | :--- |\n| `LL-001` | 2026-01-01 | `[BACKEND]` | Vieja activa | c | s |\n| `LL-002` | 2026-01-02 | `[BACKEND]` | [OBSOLETA] Vieja retirada | c | s |')
open('.agents/brain/lessons_learned.md', 'w').write(l)
PYEOF
check "el proyecto de prueba parte del esquema antiguo" '[ "$(grep "Vieja activa" .agents/brain/lessons_learned.md | awk -F"|" "{print NF-2}")" = 6 ]'
OLD_START=$($T brain search vieja 2>&1)
check "con el esquema antiguo la lectura funciona sin migrar" 'printf "%s" "$OLD_START" | grep -q "LL-001" && [ "$(grep "Vieja activa" .agents/brain/lessons_learned.md | awk -F"|" "{print NF-2}")" = 6 ]'
$T learn "Leccion nueva tras actualizar la libreria" backend "c" "s" >/dev/null
check "learn migra el esquema antiguo conservando estados" 'grep "LL-001" .agents/brain/lessons_learned.md | grep -q "ACTIVO" && grep "LL-002" .agents/brain/lessons_learned.md | grep -q "OBSOLETA" && ! grep -q "\[OBSOLETA\]" .agents/brain/lessons_learned.md'
check "la migración incorpora lecciones que solo estaban en BRAIN.md" 'grep -q "LL-003.*Solo en brain" .agents/brain/lessons_learned.md'
check "tras migrar, todas las filas tienen 8 columnas y la nueva es LL-004" '[ -z "$(grep "^| \`LL-" .agents/brain/lessons_learned.md | awk -F"|" "NF-2 != 8")" ] && grep -q "LL-004.*Leccion nueva" BRAIN.md'
check "tras migrar, BRAIN.md y la fuente coinciden y no se duplican filas" '[ "$(grep "^| \`LL-" BRAIN.md)" = "$(grep "^| \`LL-" .agents/brain/lessons_learned.md)" ] && [ "$(grep -c "LL-001" BRAIN.md)" = 1 ]'
check "migrar dos veces no añade columnas" '$T brain sync >/dev/null && [ -z "$(grep "^| \`LL-" .agents/brain/lessons_learned.md | awk -F"|" "NF-2 != 8")" ]'
# Proyecto antiguo sin lessons_learned.md: las lecciones solo viven en BRAIN.md (7 columnas)
new_project cerebro-sin-fuente
python3 - <<'PYEOF'
b = open('BRAIN.md').read()
b = b.replace('| ID | Fecha | Categoría | Problema Encontrado | Causa Raíz | Solución Aplicada (Antídoto) | Ámbito | Estado |\n| :---: | :---: | :---: | :--- | :--- | :--- | :--- | :---: |',
              '| ID | Fecha | Categoría | Problema Detectado | Causa Raíz | Solución Definitiva (Antídoto) | Estado |\n| :---: | :---: | :---: | :--- | :--- | :--- | :---: |\n| `LL-001` | 2026-01-01 | `[BACKEND]` | Solo brain uno | c | s | `ACTIVO` |\n| `LL-002` | 2026-01-02 | `[QA]` | Solo brain dos | c | s | `OBSOLETA` |')
open('BRAIN.md', 'w').write(b)
PYEOF
rm .agents/brain/lessons_learned.md
$T brain sync >/dev/null 2>&1
check "brain sync sin lessons_learned.md lo crea y no pierde las lecciones de BRAIN.md" '[ -f .agents/brain/lessons_learned.md ] && grep -q "LL-001.*Solo brain uno" BRAIN.md && grep -q "LL-002.*Solo brain dos" BRAIN.md && grep "LL-002" .agents/brain/lessons_learned.md | grep -q "OBSOLETA"'
check "las lecciones adoptadas quedan con 8 columnas e idénticas en ambos archivos" '[ -z "$(grep "^| \`LL-" BRAIN.md | awk -F"|" "NF-2 != 8")" ] && [ "$(grep "^| \`LL-" BRAIN.md)" = "$(grep "^| \`LL-" .agents/brain/lessons_learned.md)" ]'
rm .agents/brain/lessons_learned.md
git checkout -q BRAIN.md 2>/dev/null; python3 - <<'PYEOF'
b = open('BRAIN.md').read()
b = b.replace('| :---: | :---: | :---: | :--- | :--- | :--- | :--- | :---: |', '| :---: | :---: | :---: | :--- | :--- | :--- | :--- | :---: |\n| `LL-001` | 2026-01-01 | `[BACKEND]` | Ocho columnas solo en brain | c | s | `src/*.ts` | `ACTIVO` |', 1)
open('BRAIN.md', 'w').write(b)
PYEOF
$T learn "Primera leccion registrada sin archivo fuente" backend "c" "s" >/dev/null 2>&1
check "learn sin lessons_learned.md lo crea, adopta lo de BRAIN.md y numera a continuación" 'grep -q "LL-001.*Ocho columnas solo en brain" BRAIN.md && grep -q "LL-002.*Primera leccion" BRAIN.md && grep "LL-001" .agents/brain/lessons_learned.md | grep -qF "src/*.ts"'
: > "$WORK/vacio.md"; cp .agents/brain/lessons_learned.md "$WORK/ll.bak"; printf '# sin tabla\n' > .agents/brain/lessons_learned.md
check "brain sync aborta sin tocar BRAIN.md si la fuente no tiene tabla" 'cp BRAIN.md "$WORK/b2" && ! $T brain sync >/dev/null 2>&1 && cmp -s BRAIN.md "$WORK/b2"'
cat "$WORK/ll.bak" > .agents/brain/lessons_learned.md
$T learn "$(printf 'Fallo con\ttabulador en el texto')" backend "$(printf 'causa\tcon tab')" "s" >/dev/null
check "una lección con tabuladores sigue activa y visible" '$T brain search tabulador | grep -q "LL-003" && [ "$($T brain search tabulador | grep -c "ACTIVO\|OBSOLETA")" = 0 ] && ! grep -q "$(printf "\t")" .agents/brain/lessons_learned.md'
$T learn "Ruta con espacios en el nombre de carpeta" devops "c" "s" --paths " Mis Documentos/app/*.ts , , scripts/ " >/dev/null
check "el ámbito conserva espacios interiores y descarta elementos vacíos" 'grep "Ruta con espacios" .agents/brain/lessons_learned.md | grep -qF "| \`Mis Documentos/app/*.ts,scripts/\` |"'
$T add "Tarea cualquiera sin relacion" "mobile-agent" "criterio" >/dev/null
RT=$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)
check "brain for casa una ruta con espacios" '$T brain for "$RT" "/home/u/Mis Documentos/app/main.ts" | grep -q "Ruta con espacios"'
check "un ámbito acabado en / cubre los archivos del directorio" '$T brain for "$RT" scripts/deploy/run.sh | grep -q "Ruta con espacios"'
check "el glob no casa un sufijo distinto ni un directorio de nombre parecido" '! $T brain for "$RT" "Mis Documentos/app/main.ts.bak" | grep -q "Ruta con espacios" && ! $T brain for "$RT" "myscripts/x.sh" | grep -q "Ruta con espacios"'
check "brain scope y learn rechazan un ámbito vacío" '! $T brain scope LL-001 " , ," >/dev/null 2>&1 && ! $T learn "Otra leccion con ambito vacio" qa "c" "s" --paths " , " >/dev/null 2>&1'
check "brain search sin términos reales falla" '! $T brain search "  " >/dev/null 2>&1'
printf '%s\n' "| \`LL-090\` | 2026-01-01 | \`[QA]\` | Fila de seis columnas | causa seis | solucion seis |" > "$WORK/f6.txt"
awk -v f="$WORK/f6.txt" '{ print } /^\| `LL-002`/ { while ((getline l < f) > 0) print l }' BRAIN.md > "$WORK/b6" && cat "$WORK/b6" > BRAIN.md
$T brain sync >/dev/null 2>&1
check "adoptar una fila de BRAIN.md sin columna Estado conserva su solución" 'grep "LL-090" .agents/brain/lessons_learned.md | grep -q "solucion seis.*ACTIVO" && [ "$(grep "LL-090" BRAIN.md | awk -F"|" "{print NF-2}")" = 8 ]'
cp .agents/scripts/brain-lib.sh "$WORK/lib.bak" && rm .agents/scripts/brain-lib.sh
check "sin brain-lib.sh task.sh falla con un mensaje claro" '$T list 2>&1 | grep -q "instalación incompleta" && ! $T list >/dev/null 2>&1'
cp "$WORK/lib.bak" .agents/scripts/brain-lib.sh
cd "$WORK" || exit 1

# ------------------------------------------------------------------------------
section "cerebro: captura obligatoria, reincidencias, doctor y stats"
new_project captura
review() { mkdir -p .agents/reviews; printf -- '- **Revisor**: `qa-security-agent`\n' > ".agents/reviews/qa_$1.md"; }
to_qa() { $T start "$1" >/dev/null 2>&1; $T handoff "$1" >/dev/null 2>&1; }
$T add "Feature: listado de pedidos" "backend-agent" "criterio" >/dev/null; F1=$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)
to_qa "$F1"; review "$F1"
check "una tarea sin rechazos ni defecto se cierra sin lección" '$T close "$F1" >/dev/null 2>&1 && [ "$(col "$F1" 5)" = DONE ]'
git checkout -q main 2>/dev/null
$T learn "Listado de pedidos sin paginacion agota la memoria" backend "Se cargaban todas las filas" "Paginar siempre en la consulta SQL" --paths "server/pedidos/*.ts" >/dev/null
$T add "Feature: exportar pedidos" "backend-agent" "criterio" >/dev/null; F2=$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)
to_qa "$F2"; review "$F2"
REJ_OUT=$($T reject "$F2" "El listado de pedidos carga todo sin paginacion y agota la memoria" 2>&1)
check "reject avisa de la reincidencia de una lección activa" 'printf "%s" "$REJ_OUT" | grep -q "Reincidencia.*LL-001"'
check "la reincidencia queda en recurrences.md y en el historial" 'grep -q "LL-001" .agents/brain/recurrences.md && grep "$F2" .agents/brain/recurrences.md | grep -q "paginacion" && grep -q "reincidencia de LL-001" GLOBAL_STATE.md'
to_qa "$F2"
REJ2=$($T reject "$F2" "Falta el test del endpoint de exportacion" 2>&1)
check "un rechazo sin relación no cuenta como reincidencia" '! printf "%s" "$REJ2" | grep -q "Reincidencia" && [ "$(grep -c "LL-001" .agents/brain/recurrences.md)" = 1 ]'
to_qa "$F2"
check "close de una tarea con rechazos exige lección o justificación" '! $T close "$F2" >/dev/null 2>&1 && [ "$(col "$F2" 5)" = IN_REVIEW_QA ] && $T close "$F2" 2>&1 | grep -q -- "--no-lesson"'
check "close --lesson con una lección inexistente falla" '! $T close "$F2" --lesson LL-999 >/dev/null 2>&1 && [ "$(col "$F2" 5)" = IN_REVIEW_QA ]'
check "close con --lesson y --no-lesson a la vez falla" '! $T close "$F2" --lesson LL-001 --no-lesson "x" >/dev/null 2>&1'
check "close --no-lesson sin motivo real falla" '! $T close "$F2" --no-lesson "   " >/dev/null 2>&1 && [ "$(col "$F2" 5)" = IN_REVIEW_QA ]'
check "close --lesson LL-001 cierra y deja la lección en el historial" '$T close "$F2" --lesson ll-001 >/dev/null 2>&1 && [ "$(col "$F2" 5)" = DONE ] && grep "$F2" GLOBAL_STATE.md | grep -q "Lección: LL-001"'
git checkout -q main 2>/dev/null
$T add "Bug: el total sale negativo" "backend-agent" "criterio" >/dev/null; F3=$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)
to_qa "$F3"; review "$F3"
check "una corrección (Bug:/rama fix/) no se cierra sin lección aunque no tenga rechazos" 'git branch --list "fix/$F3-*" | grep -q fix/ && ! $T close "$F3" >/dev/null 2>&1'
check "close --no-lesson con motivo cierra y lo deja en el historial" '$T close "$F3" --no-lesson "Errata en un literal" >/dev/null 2>&1 && [ "$(col "$F3" 5)" = DONE ] && grep "$F3" GLOBAL_STATE.md | grep -q "Sin lección: Errata en un literal"'
git checkout -q main 2>/dev/null
$T learn "Leccion que se retira despues" qa "c" "s" >/dev/null; LOBS=$(grep "Leccion que se retira" BRAIN.md | grep -oE "LL-[0-9]+" | head -1); $T lesson-retire "$LOBS" >/dev/null
$T add "Feature: informe mensual" "backend-agent" "criterio" >/dev/null; F4=$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)
to_qa "$F4"; review "$F4"; $T reject "$F4" "uno" >/dev/null 2>&1; to_qa "$F4"
check "close --lesson con una lección OBSOLETA falla" '! $T close "$F4" --lesson "$LOBS" >/dev/null 2>&1 && [ "$(col "$F4" 5)" = IN_REVIEW_QA ]'
check "motivos genéricos no cuentan como reincidencia" 'R0=$(grep -c "LL-" .agents/brain/recurrences.md) && $T reject "$F4" "Los tests de integracion fallan al ejecutar la suite completa de pedidos" >/dev/null 2>&1 && [ "$(grep -c "LL-" .agents/brain/recurrences.md)" = "$R0" ]'
to_qa "$F4"
chmod 444 .agents/brain/recurrences.md
REJ3=$($T reject "$F4" "Otra vez el listado de pedidos sin paginacion agota la memoria" 2>&1)
check "si no se puede escribir recurrences.md el rechazo se registra igualmente" '[ "$(col "$F4" 5)" = BLOCKED ] && grep "$F4" GLOBAL_STATE.md | grep -q "Rechazo 3/3.*reincidencia de LL-001" && printf "%s" "$REJ3" | grep -q "No se pudo anotar la reincidencia"'
chmod 644 .agents/brain/recurrences.md
$T move "$F4" IN_PROGRESS >/dev/null 2>&1; $T handoff "$F4" >/dev/null 2>&1
check "reabrir una tarea BLOCKED con move no borra la obligación de lección" '[ "$(col "$F4" 6)" = 0/3 ] && ! $T close "$F4" >/dev/null 2>&1 && $T close "$F4" --lesson LL-001 >/dev/null 2>&1 && [ "$(col "$F4" 5)" = DONE ]'
git checkout -q main 2>/dev/null
check "brain doctor da el cerebro por sano" '$T brain doctor >/dev/null 2>&1'
check "brain stats resume lecciones, reincidencias y deuda" '$T brain stats | grep -q "Lecciones: 2 (1 activas, 1 obsoletas)" && $T brain stats | grep -q "Reincidencias: 1" && $T brain stats | grep -q "LL-001: 1" && $T brain stats | grep -q "\[BACKEND\] 1"'
check "validate-state.sh incluye el chequeo del cerebro y pasa" 'bash .agents/scripts/validate-state.sh | grep -q "Cerebro sin errores estructurales"'
$T learn "sed: el & en el reemplazo es el texto coincidente" devops "El reemplazo dejaba placeholders corruptos y patron sin acotar" "Escapar el ampersand y acotar patrones con [^]]" >/dev/null
$T add "Feature: plantilla de inicio" "devops-cloud-agent" "criterio" >/dev/null; F5=$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)
to_qa "$F5"; REJ_PAR=$($T reject "$F5" "Los reemplazos con sed corrompieron los placeholders y patrones" 2>&1)
check "detector de reincidencia compara causa raiz y plurales (TD-004)" 'printf "%s" "$REJ_PAR" | grep -q "Reincidencia.*LL-00[0-9]"'
to_qa "$F5"; $T close "$F5" --no-lesson "Prueba de parafrasis" >/dev/null 2>&1; git checkout -q main 2>/dev/null
cp .agents/brain/lessons_learned.md "$WORK/ll.doc"; cp BRAIN.md "$WORK/brain.doc"
grep "LL-001" .agents/brain/lessons_learned.md >> .agents/brain/lessons_learned.md
check "brain doctor detecta un ID duplicado y sale con error" '! $T brain doctor >/dev/null 2>&1 && $T brain doctor 2>&1 | grep -q "ERROR: LL-001 está duplicada"'
check "validate-state.sh falla si el cerebro tiene errores" '! bash .agents/scripts/validate-state.sh >/dev/null 2>&1'
cat "$WORK/ll.doc" > .agents/brain/lessons_learned.md
sed -i.bak 's/`ACTIVO` |$/`RARO` |/' .agents/brain/lessons_learned.md && rm -f .agents/brain/lessons_learned.md.bak
check "brain doctor detecta un Estado inválido y la desincronización con BRAIN.md" '$T brain doctor 2>&1 | grep -q "Estado inválido" && $T brain doctor 2>&1 | grep -q "no coincide con lessons_learned.md"'
cat "$WORK/ll.doc" > .agents/brain/lessons_learned.md
printf '%s\n' "| \`LL-009\` | 2026-01-01 | \`[QA]\` | Texto con | barra sin escapar | causa | solucion | \`*\` | \`ACTIVO\` |" >> .agents/brain/lessons_learned.md
check "brain doctor detecta una fila con columnas de más" '$T brain doctor 2>&1 | grep -q "ERROR: LL-00[0-9] tiene 9 columnas"'
cat "$WORK/ll.doc" > .agents/brain/lessons_learned.md
$T learn "Leccion a medias sin causa" qa >/dev/null
check "una lección sin causa ni solución es un aviso, no un error" '$T brain doctor >/dev/null 2>&1 && $T brain doctor 2>&1 | grep -q "AVISO: LL-00[0-9] no documenta la causa"'
check "doctor y stats no modifican ningún archivo" 'cp BRAIN.md "$WORK/b9" && cp .agents/brain/lessons_learned.md "$WORK/l9" && $T brain doctor >/dev/null 2>&1; $T brain stats >/dev/null && cmp -s BRAIN.md "$WORK/b9" && cmp -s .agents/brain/lessons_learned.md "$WORK/l9"'
mkdir .agents/.task_lock 2>/dev/null
check "brain doctor, stats, search y for no esperan el lock de escritura" '$T brain doctor >/dev/null 2>&1; $T brain stats >/dev/null 2>&1 && $T brain search pedidos >/dev/null 2>&1'
rmdir .agents/.task_lock 2>/dev/null
$T debt "Deuda sin sincronizar en BRAIN" TASK-001 "Resolver luego" media >/dev/null
cp BRAIN.md "$WORK/b_td.bak"
sed -i.bak '/TD-001/d' BRAIN.md && rm -f BRAIN.md.bak
check "brain doctor detecta desincronización de deuda técnica en BRAIN.md" '! $T brain doctor >/dev/null 2>&1 && $T brain doctor 2>&1 | grep -q "deuda técnica de BRAIN.md no coincide"'
$T brain sync >/dev/null 2>&1
check "brain sync restaura el resumen de deuda en BRAIN.md" 'grep -q "TD-001" BRAIN.md && $T brain doctor >/dev/null 2>&1'
cp .agents/brain/tech_debt.md "$WORK/td_doc.bak"
: > .agents/brain/tech_debt.md
$T brain sync >/dev/null 2>&1
check "brain sync con tech_debt.md vacío no borra BRAIN.md (BUG-TASK-039-1)" '[ -s BRAIN.md ] && grep -q "LL-001" BRAIN.md && grep -q "TD-001" BRAIN.md'
check "brain doctor detecta tech_debt.md sin cabecera" '! $T brain doctor >/dev/null 2>&1 && $T brain doctor 2>&1 | grep -q "tech_debt.md no tiene la tabla"'
cat "$WORK/td_doc.bak" > .agents/brain/tech_debt.md
$T brain sync >/dev/null 2>&1
cp GLOBAL_STATE.md "$WORK/gs_dup.bak"
grep "| \`TASK-001\`" GLOBAL_STATE.md >> GLOBAL_STATE.md
check "validate-state.sh detecta IDs de tarea duplicados" '! bash .agents/scripts/validate-state.sh >/dev/null 2>&1 && bash .agents/scripts/validate-state.sh 2>&1 | grep -q "IDs de tarea duplicados"'
cat "$WORK/gs_dup.bak" > GLOBAL_STATE.md
$T add "Tarea con agente experimental" "agente-fantasma" "criterio" >/dev/null
check "validate-state.sh avisa sobre agentes desconocidos sin fallar" 'bash .agents/scripts/validate-state.sh 2>&1 | grep -q "agente-fantasma"'
cd "$WORK" || exit 1

# ------------------------------------------------------------------------------
section "hook de Claude Code: brain-context.sh (el cerebro va al agente)"
new_project contexto
BC=./.agents/scripts/brain-context.sh
export TMPDIR="$WORK/tmp-hook"; mkdir -p "$TMPDIR"
ctx_json() { printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" "$2"; }
ctx() { ctx_json "$1" "$2" | CLAUDE_PROJECT_DIR="$PWD" bash $BC; }
ctx_text() { ctx "$1" "$2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])' 2>/dev/null; }
check "init-project registra el hook del cerebro en .claude/settings.json" 'grep -q "brain-context.sh" .claude/settings.json && grep -q "require-active-task.sh" .claude/settings.json && python3 -m json.tool .claude/settings.json >/dev/null'
$T learn "Consulta sin indice en pedidos" database "Falta indice" "Crear indice en cada FK" --paths "server/db/*.sql,migrations/" >/dev/null
$T learn "Leccion general sin ambito" backend "c" "s" >/dev/null
$T learn "Token con \"comillas\" y barra \\ invertida" backend "c" "Usar middleware" --paths "server/auth/*.ts" >/dev/null
$T learn "Documentacion con enlaces rotos" docs "Enlace antiguo" "Validar rutas markdown" --paths "docs/*.md" >/dev/null
mkdir -p "$TMPDIR/maestro-brain-context" && touch "$TMPDIR/maestro-brain-context/seen_caducada"
F="$TMPDIR/maestro-brain-context/seen_caducada" python3 -c 'import os,time; t=time.time()-8*86400; os.utime(os.environ["F"], (t,t))'
check "sin tarea IN_PROGRESS no muestra ni marca vista la lección en archivos de código (TD-003)" '[ -z "$(ctx s2 "$PWD/server/db/001.sql")" ]'
check "sin tarea IN_PROGRESS sí muestra la lección en documentación permitida" 'ctx_text s_doc "$PWD/docs/guia.md" | grep -q "LL-004"'
$T add "Editar con hook activo" "backend-agent" "criterio" >/dev/null
$T start "$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)" >/dev/null
check "purga archivos de sesión con más de 7 días de antigüedad" '! [ -e "$TMPDIR/maestro-brain-context/seen_caducada" ]'
check "sin lecciones para la ruta no imprime nada y sale con 0" '[ -z "$(ctx s1 "$PWD/src/app/home.ts")" ] && ctx s1 "$PWD/src/app/home.ts"'
check "muestra la lección cuyo ámbito cubre el archivo, con su antídoto" 'ctx_text s2 "$PWD/server/db/001.sql" | grep -q "LL-001.*Consulta sin indice" && ctx_text s2b "$PWD/server/db/001.sql" | grep -q "Antídoto: Crear indice en cada FK"'
check "la salida es JSON válido de PreToolUse aunque el texto tenga comillas y barras" 'ctx s3 "$PWD/server/auth/login.ts" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d[\"hookSpecificOutput\"][\"hookEventName\"] == \"PreToolUse\"; assert \"comillas\" in d[\"hookSpecificOutput\"][\"additionalContext\"]"'
check "cada lección se muestra una sola vez por sesión" '[ -n "$(ctx s4 "$PWD/server/db/a.sql")" ] && [ -z "$(ctx s4 "$PWD/server/db/b.sql")" ] && [ -n "$(ctx s5 "$PWD/server/db/b.sql")" ]'
check "en la misma sesión sí muestra una lección distinta" 'ctx_text s4 "$PWD/server/auth/login.ts" | grep -q "LL-003"'
check "las lecciones generales (*) no se inyectan al editar" '! ctx_text s6 "$PWD/server/db/001.sql" | grep -q "LL-002"'
check "acepta rutas relativas y un ámbito de directorio" 'ctx_text s7 "migrations/2026/0001.sql" | grep -q "LL-001"'
check "ignora archivos de fuera del proyecto" '[ -z "$(ctx s8 "/tmp/otro/server/db/x.sql")" ]'
$T lesson-retire LL-001 >/dev/null
check "una lección OBSOLETA deja de mostrarse" '[ -z "$(ctx s9 "$PWD/server/db/001.sql")" ]'
check "MAESTRO_BRAIN_CONTEXT=0 lo desactiva" '[ -z "$(ctx_json s10 "$PWD/server/auth/login.ts" | MAESTRO_BRAIN_CONTEXT=0 CLAUDE_PROJECT_DIR="$PWD" bash $BC)" ]'
check "entrada que no es JSON, vacía o sin ruta: sale con 0 y sin salida" '[ -z "$(printf "no-json" | CLAUDE_PROJECT_DIR="$PWD" bash $BC)" ] && printf "" | CLAUDE_PROJECT_DIR="$PWD" bash $BC && printf "{\"tool_input\":{}}" | CLAUDE_PROJECT_DIR="$PWD" bash $BC'
check "sin session_id muestra la lección y no falla" 'printf "{\"tool_input\":{\"file_path\":\"server/auth/x.ts\"}}" | CLAUDE_PROJECT_DIR="$PWD" bash $BC | grep -q "LL-003"'
check "un session_id hostil no escribe fuera del directorio temporal" 'ctx "../../../x/../pwned" "$PWD/server/auth/y.ts" >/dev/null; [ ! -e "$WORK/pwned" ] && [ ! -e "$TMPDIR/../pwned" ] && [ -z "$(find "$TMPDIR/maestro-brain-context" -name "*..*" 2>/dev/null)" ]'
mkdir -p "$TMPDIR/maestro-brain-context/.lock_s_race"
ctx s_race "$PWD/server/auth/login.ts" >/dev/null
check "brain-context.sh no roba ni borra un lock ajeno bajo contención (BUG-TASK-039-2)" '[ -d "$TMPDIR/maestro-brain-context/.lock_s_race" ]'
rmdir "$TMPDIR/maestro-brain-context/.lock_s_race" 2>/dev/null || true
check "sin python3 sale con 0 y en silencio" 'NOPYH="$WORK/nopy-hook"; mkdir -p "$NOPYH"; for d in /bin /usr/bin; do for f in "$d"/*; do b=$(basename "$f"); case "$b" in python*) continue ;; esac; [ -e "$NOPYH/$b" ] || ln -s "$f" "$NOPYH/$b" 2>/dev/null; done; done; OUT=$(ctx_json s11 "$PWD/server/auth/login.ts" | PATH="$NOPYH" CLAUDE_PROJECT_DIR="$PWD" bash $BC); [ $? -eq 0 ] && [ -z "$OUT" ]'
mv .agents/brain/lessons_learned.md "$WORK/ll.hook"; mv BRAIN.md "$WORK/brain.hook"
check "sin cerebro en el proyecto sale con 0 y en silencio" '[ -z "$(ctx s12 "$PWD/server/auth/login.ts")" ] && ctx s12 "$PWD/server/auth/login.ts"'
mv "$WORK/ll.hook" .agents/brain/lessons_learned.md; mv "$WORK/brain.hook" BRAIN.md
check "el hook no modifica ningún archivo del proyecto" '[ -z "$(git status --porcelain -- BRAIN.md .agents/brain GLOBAL_STATE.md | grep -v "^ M\|^M " )" ] && cp BRAIN.md "$WORK/bh" && cp .agents/brain/lessons_learned.md "$WORK/lh" && ctx s13 "$PWD/server/auth/login.ts" >/dev/null && cmp -s BRAIN.md "$WORK/bh" && cmp -s .agents/brain/lessons_learned.md "$WORK/lh"'
OLDSET="$WORK/proy-settings-viejo"; mkdir -p "$OLDSET" && git -C "$OLDSET" init -q -b main
bash "$ROOT/.agents/scripts/init-project.sh" "Viejo" "$OLDSET" >/dev/null 2>&1
printf '{"hooks":{"PreToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"bash x/require-active-task.sh"}]}]}}\n' > "$OLDSET/.claude/settings.json"
echo "# Reglas personalizadas del proyecto" >> "$OLDSET/AGENTS.md"
check "init-project --update avisa del hook y drift de AGENTS.md sin sobrescribirlos" 'cp "$OLDSET/.claude/settings.json" "$WORK/set.bak" && cp "$OLDSET/AGENTS.md" "$WORK/ag.bak" && UPD_OUT=$(bash "$ROOT/.agents/scripts/init-project.sh" --update "$OLDSET" 2>&1) && printf "%s" "$UPD_OUT" | grep -q "brain-context.sh" && printf "%s" "$UPD_OUT" | grep -q "AGENTS.md" && cmp -s "$OLDSET/.claude/settings.json" "$WORK/set.bak" && cmp -s "$OLDSET/AGENTS.md" "$WORK/ag.bak"'
unset TMPDIR
cd "$WORK" || exit 1

# ------------------------------------------------------------------------------
section "robustez de task.sh (locale, permisos, escapes, sin python3)"
new_project robusto
chmod 644 GLOBAL_STATE.md BRAIN.md .agents/brain/tech_debt.md .agents/brain/lessons_learned.md
$T add "Tarea de permisos" "backend-agent" "criterio" >/dev/null
$T learn "Leccion para permisos del archivo" backend "c" "s" >/dev/null
$T debt "Deuda con la palabra SALDADA en el texto" TASK-001 "accion" baja >/dev/null
perm() { ls -l "$1" | cut -c1-10; }
check "task.sh conserva los permisos de GLOBAL_STATE.md, BRAIN.md y el cerebro" '[ "$(perm GLOBAL_STATE.md)" = "-rw-r--r--" ] && [ "$(perm BRAIN.md)" = "-rw-r--r--" ] && [ "$(perm .agents/brain/tech_debt.md)" = "-rw-r--r--" ] && [ "$(perm .agents/brain/lessons_learned.md)" = "-rw-r--r--" ]'
check "debt-resolve salda una deuda cuyo texto contiene la palabra SALDADA" '$T debt-resolve TD-001 >/dev/null && ! $T debt-resolve TD-001 >/dev/null 2>&1'
check "los mensajes no interpretan secuencias de escape del usuario" '$T learn "Ruta C:\\nuevo\\tabla rota" devops "c" "s" | grep -qF "C:\\nuevo\\tabla"'
check "die conserva el salto de línea propio del mensaje de uso" '[ "$($T add 2>&1 | wc -l | tr -d " ")" -ge 2 ]'
# PATH sin python3: enlaces a todas las herramientas del sistema salvo python*
NOPY="$WORK/nopy-bin"; mkdir -p "$NOPY"
for d in /bin /usr/bin "$(dirname "$(command -v git)")"; do
  for f in "$d"/*; do
    b=$(basename "$f"); case "$b" in python*) continue ;; esac
    [ -e "$NOPY/$b" ] || ln -s "$f" "$NOPY/$b" 2>/dev/null
  done
done
check "el PATH de prueba no tiene python3" '! env PATH="$NOPY" bash -c "command -v python3" >/dev/null 2>&1'
PATH="$NOPY" LC_ALL=C $T learn "Paginación incorrecta en migración automática" database "c" "s" >/dev/null 2>&1
check "sin python3 y en locale C, learn detecta el duplicado en mayúsculas" '! PATH="$NOPY" LC_ALL=C $T learn "PAGINACIÓN INCORRECTA EN MIGRACIÓN AUTOMÁTICA" database "c" "s" >/dev/null 2>&1'
check "sin python3 y en locale C, learn detecta el duplicado sin tildes" '! PATH="$NOPY" LC_ALL=C $T learn "Paginacion incorrecta en migracion automatica" database "c" "s" >/dev/null 2>&1'
check "sin python3, learn sigue aceptando una lección distinta" 'PATH="$NOPY" LC_ALL=C $T learn "Timeout al conectar con el proveedor" backend "c" "s" >/dev/null 2>&1'
$T add "Auditoría de diagnóstico ñandú" "backend-agent" "criterio" >/dev/null
PATH="$NOPY" LC_ALL=C $T start "$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)" >/dev/null 2>&1
check "sin python3 y en locale C, el slug de la rama no pierde letras con tilde" 'git branch --show-current | grep -q "auditoria-de-diagnostico-nandu"'
git checkout -q main 2>/dev/null
ONEARG="$WORK/un-arg"; mkdir -p "$ONEARG" && git -C "$ONEARG" init -q -b main
check "init-project.sh con un solo argumento instala en el directorio actual" '(cd "$ONEARG" && bash "$ROOT/.agents/scripts/init-project.sh" "Solo Nombre" >/dev/null 2>&1) && grep -q "Solo Nombre" "$ONEARG/GLOBAL_STATE.md"'
cd "$WORK" || exit 1

# ------------------------------------------------------------------------------
section "hooks de git (pre-commit / commit-msg) y task.sh commit"
new_project hooks
bash ./.agents/scripts/install-hooks.sh >/dev/null
FAKE_KEY="sk""-ant-api03-$(printf 'a%.0s' {1..32})"
FAKE_PEM="-----BEGIN ""PRIVATE KEY-----"

echo "const key = \"$FAKE_KEY\"" > leak.js; git add leak.js
check "pre-commit bloquea una clave sk-" '! git commit -qm "feat(TASK-001): x" >/dev/null 2>&1'
git rm -q --cached leak.js; rm leak.js

FAKE_STRIPE="sk""_live_$(printf 'b%.0s' {1..30})"
echo "STRIPE_SECRET_KEY=$FAKE_STRIPE" > billing.ts; git add billing.ts
check "pre-commit bloquea una clave de Stripe (sk_live_)" '! git commit -qm "feat(TASK-001): x" >/dev/null 2>&1'
git rm -q --cached billing.ts; rm billing.ts

echo "$FAKE_PEM" > id.pem.txt; git add id.pem.txt
check "pre-commit bloquea una clave privada" '! git commit -qm "feat(TASK-001): x" >/dev/null 2>&1'
git rm -q --cached id.pem.txt; rm id.pem.txt

echo "SECRET=1" > .env.production; git add -f .env.production
check "pre-commit bloquea archivos .env" '! git commit -qm "feat(TASK-001): x" >/dev/null 2>&1'
git rm -q --cached .env.production; rm .env.production

printf 'const task-list = 1\nconst disk-size = 2\n' > ok.js; echo "EXAMPLE=$FAKE_KEY # secret-scan:allow" > doc.md
git add ok.js doc.md .env.example
check "pre-commit acepta 'task-', 'disk-' y líneas con secret-scan:allow" 'git commit -qm "feat(TASK-001): codigo limpio" >/dev/null 2>&1'

echo "x" >> ok.js; git add ok.js
check "commit-msg rechaza mensajes sin TASK-ID" '! git commit -qm "arreglos varios" >/dev/null 2>&1'
check "commit-msg rechaza TASK-ID inexistente en el tablero" '! git commit -qm "fix(TASK-999): arreglos" >/dev/null 2>&1'
check "commit-msg acepta tipo(TASK-XXX): mensaje" 'git commit -qm "fix(TASK-001): ajustar ok" >/dev/null 2>&1'

echo "y" >> ok.js; echo "nuevo" > nuevo.txt
$T commit TASK-001 "actualizar ok" fix >/dev/null 2>&1
check "task.sh commit incluye cambios versionados" '[ "$(git log -1 --pretty=%s)" = "fix(TASK-001): actualizar ok" ]'
check "task.sh commit no añade archivos nuevos a ciegas" '[ -n "$(git ls-files --others --exclude-standard | grep nuevo.txt)" ]'
echo "z" >> ok.js
$T commit TASK-001 "con autoria" fix --trailer "Co-Authored-By: Bot <bot@example.com>" >/dev/null 2>&1
check "task.sh commit --trailer añade la línea de autoría al cuerpo" '[ "$(git log -1 --pretty=%s)" = "fix(TASK-001): con autoria" ] && git log -1 --pretty=%b | grep -qx "Co-Authored-By: Bot <bot@example.com>"'
echo "w" >> ok.js
MAESTRO_COMMIT_TRAILER="Co-Authored-By: Env <env@example.com>" $T commit TASK-001 "con autoria por entorno" >/dev/null 2>&1
check "MAESTRO_COMMIT_TRAILER añade el trailer y el tipo por defecto es feat" '[ "$(git log -1 --pretty=%s)" = "feat(TASK-001): con autoria por entorno" ] && git log -1 --pretty=%b | grep -q "Env <env@example.com>"'
echo "v" >> ok.js
check "task.sh commit rechaza un trailer sin formato Clave: valor" '! $T commit TASK-001 "malo" fix --trailer "sin formato" >/dev/null 2>&1'
check "task.sh commit rechaza un trailer con salto de línea" '! $T commit TASK-001 "malo" fix --trailer "$(printf "Co-Authored-By: A <a@example.com>\nfix(TASK-999): inyectado")" >/dev/null 2>&1'
git checkout -q ok.js 2>/dev/null; git reset -q 2>/dev/null

# ------------------------------------------------------------------------------
section "scan-secrets.sh --all (modo CI)"
# Copia del repositorio de skills en un git temporal para escanear todos sus archivos
mkdir -p "$WORK/library" && (cd "$ROOT" && tar cf - --exclude .git --exclude .DS_Store .) | (cd "$WORK/library" && tar xf -)
git -C "$WORK/library" init -q && git -C "$WORK/library" add -A
check "el repositorio de skills no contiene secretos" '(cd "$WORK/library" && bash .agents/scripts/scan-secrets.sh --all >/dev/null)'
echo "token = \"$FAKE_KEY\"" > "$WORK/library/config.js" && git -C "$WORK/library" add config.js
check "scan-secrets --all detecta una clave versionada" '! (cd "$WORK/library" && bash .agents/scripts/scan-secrets.sh --all >/dev/null)'

# ------------------------------------------------------------------------------
section "scan-secrets.sh --branch (handoff y QA)"
new_project branchscan
S=./.agents/scripts/scan-secrets.sh
git checkout -qb fix/TASK-001-x
echo "const limpio = 1" > clean.ts && git add clean.ts && git commit -qm "fix(TASK-001): limpio" --no-verify
check "--branch sin secretos en la rama sale limpio" 'bash $S --branch >/dev/null'
echo "token = \"$FAKE_KEY\"" > leak.ts && git add leak.ts && git commit -qm "fix(TASK-001): fuga" --no-verify
check "--staged no ve la clave ya commiteada (por eso QA no lo usa)" 'bash $S --staged >/dev/null'
check "--branch detecta una clave commiteada en la rama" '! bash $S --branch >/dev/null'
# Se descarta el commit de la fuga para que el historial no haga pasar los casos siguientes
git reset -q --hard HEAD~1
check "--branch vuelve a salir limpio sin el commit de la fuga" 'bash $S --branch >/dev/null'
echo "token = \"$FAKE_KEY\"" >> clean.ts
check "--branch detecta una clave sin commitear en un archivo versionado" '! bash $S --branch >/dev/null'
git checkout -q clean.ts && echo "token = \"$FAKE_KEY\"" > nuevo.ts
check "--branch detecta una clave en un archivo nuevo sin versionar" '! bash $S --branch >/dev/null'
rm nuevo.ts
check "--branch con base inexistente falla con exit 2" 'bash $S --branch no-existe >/dev/null 2>&1; [ $? -eq 2 ]'
check "--branch con base que empieza por '-' falla con exit 2" 'bash $S --branch --help >/dev/null 2>&1; [ $? -eq 2 ]'
echo "token = \"$FAKE_KEY\"" > "configuración.ts"
check "--branch detecta una clave en un archivo con nombre no ASCII" '! bash $S --branch >/dev/null'
git add "configuración.ts"
check "--staged detecta una clave en un archivo con nombre no ASCII" '! bash $S --staged >/dev/null'
check "--all detecta una clave en un archivo con nombre no ASCII" '! bash $S --all >/dev/null'
git commit -qm "fix(TASK-001): fuga con tilde" --no-verify && git rm -q "configuración.ts" && git commit -qm "fix(TASK-001): quitar" --no-verify
check "--branch detecta una clave commiteada y borrada después (historial)" 'bash $S --branch | grep -q "historial de la rama"'
git checkout -q main && git checkout -qb fix/TASK-001-env
mkdir -p producción && echo "SECRET=1" > producción/.env && git add -f producción/.env && git commit -qm "fix(TASK-001): env" --no-verify
git rm -rq producción && git commit -qm "fix(TASK-001): quitar env" --no-verify
check "--branch detecta un .env commiteado y borrado en una carpeta no ASCII" '! bash $S --branch >/dev/null'
# TD-001: rutas con comilla doble o barra invertida, .env por rename y lineas que empiezan por "++ "
git checkout -q main && git checkout -qb fix/TASK-001-ruta
echo "token = \"$FAKE_KEY\"" > 'we"ird.ts'
check "--branch detecta una clave en un archivo con comilla doble en el nombre" '! bash $S --branch >/dev/null'
git add 'we"ird.ts'
check "--staged detecta una clave en un archivo con comilla doble en el nombre" '! bash $S --staged >/dev/null'
check "--all detecta una clave en un archivo con comilla doble en el nombre" '! bash $S --all >/dev/null'
git reset -q && rm 'we"ird.ts'
echo "token = \"$FAKE_KEY\"" > 'back\slash.ts'
check "--branch detecta una clave en un archivo con barra invertida en el nombre" '! bash $S --branch >/dev/null'
rm 'back\slash.ts'
check "--branch vuelve a salir limpio tras quitar los archivos" 'bash $S --branch >/dev/null'
echo "A=1" > ambiente.txt && git add ambiente.txt && git commit -qm "fix(TASK-001): ambiente" --no-verify
git mv ambiente.txt .env && git commit -qm "fix(TASK-001): renombrar a env" --no-verify && git rm -q -f .env && git commit -qm "fix(TASK-001): quitar env" --no-verify
check "--branch detecta un .env creado por rename y borrado despues (historial)" '! bash $S --branch >/dev/null'
git checkout -q main && git checkout -qb fix/TASK-001-plus
printf '++ token = "%s"\n' "$FAKE_KEY" > plus.txt && git add plus.txt && git commit -qm "fix(TASK-001): plus" --no-verify
git rm -q plus.txt && git commit -qm "fix(TASK-001): quitar plus" --no-verify
check "--branch detecta en el historial una linea que empieza por '++ '" '! bash $S --branch >/dev/null'
cd "$WORK" || exit 1

# ------------------------------------------------------------------------------
section "hook de Claude Code: require-active-task.sh"
new_project hook
H=./.agents/scripts/require-active-task.sh
edit_json() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1"; }
check "init-project instala .claude/settings.json con el hook" 'grep -q "require-active-task.sh" .claude/settings.json'
check "sin tarea IN_PROGRESS bloquea código (exit 2)" 'edit_json "$PWD/apps/api/src/app.ts" | CLAUDE_PROJECT_DIR="$PWD" bash $H 2>/dev/null; [ $? -eq 2 ]'
check "el mensaje de bloqueo indica /nueva-tarea" 'edit_json "$PWD/a.ts" | CLAUDE_PROJECT_DIR="$PWD" bash $H 2>&1 | grep -q "/nueva-tarea"'
check "Markdown y docs/ siempre permitidos" 'edit_json "$PWD/docs/product/prd.md" | CLAUDE_PROJECT_DIR="$PWD" bash $H && edit_json "$PWD/GLOBAL_STATE.md" | CLAUDE_PROJECT_DIR="$PWD" bash $H'
check "archivos fuera del proyecto permitidos" 'edit_json "/tmp/otro/x.ts" | CLAUDE_PROJECT_DIR="$PWD" bash $H'
check "MAESTRO_ALLOW_UNTRACKED=1 permite la edición" 'edit_json "$PWD/a.ts" | MAESTRO_ALLOW_UNTRACKED=1 CLAUDE_PROJECT_DIR="$PWD" bash $H'
$T add "Bug: login 500 IN_PROGRESS" "backend-agent" "test" >/dev/null
check "'IN_PROGRESS' en la descripción no cuenta como tarea activa" 'edit_json "$PWD/a.ts" | CLAUDE_PROJECT_DIR="$PWD" bash $H 2>/dev/null; [ $? -eq 2 ]'
$T start TASK-003 >/dev/null
check "con una tarea IN_PROGRESS permite editar código" 'edit_json "$PWD/a.ts" | CLAUDE_PROJECT_DIR="$PWD" bash $H'
check "require-active-task.sh bloquea con exit 2 si falta python3" 'bash -c "NO_PY=\$(mktemp -d); ln -s \$(which bash) \"\$NO_PY/bash\"; PATH=\"\$NO_PY\" \"\$NO_PY/bash\" '$H' 2>/dev/null; ret=\$?; rm -rf \"\$NO_PY\"; exit \$ret"; [ $? -eq 2 ]'
rm GLOBAL_STATE.md
check "sin GLOBAL_STATE.md no actúa" 'edit_json "$PWD/a.ts" | CLAUDE_PROJECT_DIR="$PWD" bash $H'

# ------------------------------------------------------------------------------
section "tests/triggers/run_claude.py: proyecto sembrado (sin llamar a Claude)"
# Si task.sh cambia sus transiciones, el arnés de triggers debe seguir pudiendo sembrar el tablero
SEEDED=$(cd "$ROOT" && python3 -c "import sys; sys.path.insert(0, 'tests/triggers'); import run_claude; print(run_claude.make_project())" 2>/dev/null)
check "make_project() crea el proyecto sembrado" '[ -n "$SEEDED" ] && [ -f "$SEEDED/GLOBAL_STATE.md" ]'
check "las tareas sembradas tienen el estado de cases.json" '(cd "$SEEDED" && [ "$(col TASK-003 5)" = IN_PROGRESS ] && [ "$(col TASK-004 5)" = IN_REVIEW_QA ])'
check "el proyecto sembrado queda en main" '[ "$(git -C "$SEEDED" branch --show-current)" = main ]'
[ -n "$SEEDED" ] && rm -rf "$SEEDED"

# ------------------------------------------------------------------------------
section "test-flow.sh (ciclo completo de una tarea)"
check "el flujo add -> handoff -> reject x3 -> close -> merge pasa de punta a punta" 'bash "$ROOT/tests/test-flow.sh" >/dev/null'

section "test-skills.sh y evals (linters y cobertura)"
run_skills_lint() {
  local name="$1" content="$2" extra_file="${3:-}"
  local fake; fake="$(mktemp -d "$WORK/skills.XXXXXX")"
  mkdir -p "$fake/.agents/skills/$name" "$fake/tests"
  cp "$ROOT/tests/test-skills.sh" "$fake/tests/test-skills.sh"
  [ -n "$extra_file" ] && touch "$fake/$extra_file"
  printf '%s\n' "$content" > "$fake/.agents/skills/$name/SKILL.md"
  bash "$fake/tests/test-skills.sh" >/dev/null 2>&1
}

check "auditoría estructural de skills sin errores" 'bash "$ROOT/tests/test-skills.sh" >/dev/null'
check "linter de descripciones (lint_descriptions.py) sin problemas" 'python3 "$ROOT/tests/triggers/lint_descriptions.py" >/dev/null'
check "test-skills.sh sale con exit 1 ante errores" '! run_skills_lint broken-agent "---
name: broken-agent
description: corta
---
# broken"'
check "test-skills.sh rechaza YAML sin cierre ---" '! run_skills_lint no-close "---
name: no-close
description: Skill de prueba completa. Usar en regresion.
# Sin cierre YAML
---
## Pasos
- [ ] paso
## Prohibido
- Nada"'
check "test-skills.sh rechaza description sin Usar" '! run_skills_lint no-usar "---
name: no-usar
description: Skill de prueba suficientemente larga sin trigger valido.
---
# Sin Usar
## Pasos
- [ ] paso
## Prohibido
- Nada"'
check "test-skills.sh exige Prohibido en skills de flujo y técnica" '! run_skills_lint fake-flow "---
name: fake-flow
description: Skill de flujo de prueba. Usar en tests.
---
# Fake Flow
## Pasos
- [ ] paso"'
check "test-skills.sh valida stack-* sin exigir Pasos ni Prohibido" 'run_skills_lint stack-fake "---
name: stack-fake
description: Convenciones de stack falso. Usar en pruebas.
---
# Stack Fake
## Convenciones
Solo texto."'
check "test-skills.sh detecta enlaces rotos a raíz" '! run_skills_lint bad-link "---
name: bad-link
description: Skill con enlace roto. Usar en pruebas.
---
# Bad Link
## Pasos
Ver [falta](../../../NO_EXISTE.md)
- [ ] paso
## Prohibido
- Nada"'
check "test-skills.sh acepta enlaces relativos válidos a raíz" 'run_skills_lint good-link "---
name: good-link
description: Skill con enlace valido. Usar en pruebas.
---
# Good Link
## Pasos
Ver [AGENTS](../../../AGENTS.md)
- [ ] paso
## Prohibido
- Nada" "AGENTS.md"'
check "evals.json es válido y referencia skills y fixtures existentes" 'python3 - "$ROOT" <<'"'"'PY'"'"'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
data = json.loads((root / "tests/evals/evals.json").read_text(encoding="utf-8"))
evals = data.get("evals", [])
assert len(evals) >= 8, f"se esperaban >=8 evals, hay {len(evals)}"
for ev in evals:
    assert (root / ".agents/skills" / ev["skill"] / "SKILL.md").is_file(), ev["skill"]
    assert ev.get("checks"), ev["id"]
    for fx in re.findall(r"\$FIXTURES/([A-Za-z0-9_.-]+)", ev.get("setup", "")):
        assert (root / "tests/evals/fixtures" / fx).is_file(), fx
PY'

# ------------------------------------------------------------------------------
section "init-project.sh --adopt (brownfield)"
BROWN="$WORK/brownfield-app"
mkdir -p "$BROWN/src" "$BROWN/docs" "$BROWN/.claude" "$BROWN/.git/hooks"
echo 'console.log("legacy");' > "$BROWN/src/index.ts"
echo "# App Heredada" > "$BROWN/README.md"
echo "custom=secret_placeholder" > "$BROWN/.env.example"
echo "node_modules/" > "$BROWN/.gitignore"
echo "# Guia previa del repo" > "$BROWN/CLAUDE.md"
echo '{"permissions":{}}' > "$BROWN/.claude/settings.json"
echo "# Arquitecto original" > "$BROWN/docs/architecture.md"
cat > "$BROWN/.git/hooks/pre-commit" <<'EOF_HOOK'
#!/usr/bin/env bash
echo "custom hook"
EOF_HOOK
chmod +x "$BROWN/.git/hooks/pre-commit"

check "--adopt falla si destino no existe o si se combina con --update" '! bash "$ROOT/.agents/scripts/init-project.sh" --adopt "$WORK/no-existe" >/dev/null 2>&1 && ! bash "$ROOT/.agents/scripts/init-project.sh" --update --adopt "$BROWN" >/dev/null 2>&1'
ADOPT_OUT=$(bash "$ROOT/.agents/scripts/init-project.sh" --adopt "$BROWN" 2>&1)
check "--adopt instala entorno y muestra guía /adoptar-proyecto" '[ -d "$BROWN/.agents/skills/adoptar-proyecto" ] && [ -f "$BROWN/GLOBAL_STATE.md" ] && [ -f "$BROWN/BRAIN.md" ] && printf "%s" "$ADOPT_OUT" | grep -q "/adoptar-proyecto"'
check "--adopt conserva código, docs, .gitignore, .env.example y settings previos" 'grep -q "legacy" "$BROWN/src/index.ts" && grep -q "# App Heredada" "$BROWN/README.md" && grep -q "custom=secret_placeholder" "$BROWN/.env.example" && grep -q "node_modules/" "$BROWN/.gitignore" && grep -q "permissions" "$BROWN/.claude/settings.json" && grep -q "# Arquitecto original" "$BROWN/docs/architecture.md"'
check "--adopt conserva hooks custom en .git/hooks y añade @AGENTS.md al CLAUDE.md previo" 'grep -q "custom hook" "$BROWN/.git/hooks/pre-commit" && grep -q "# Guia previa del repo" "$BROWN/CLAUDE.md" && grep -q "^@AGENTS.md" "$BROWN/CLAUDE.md"'
check "--adopt genera GLOBAL_STATE.md sin tareas ficticias de plantilla ni docs/product vacío" '! grep -qE "^\| *\`?TASK-00[12]" "$BROWN/GLOBAL_STATE.md" && grep -q "brownfield-app" "$BROWN/GLOBAL_STATE.md" && [ ! -d "$BROWN/docs/product" ]'

cp "$BROWN/GLOBAL_STATE.md" "$WORK/gs.adopt.bak"
echo "custom-agents" > "$BROWN/AGENTS.md"
bash "$ROOT/.agents/scripts/init-project.sh" --adopt "$BROWN" >/dev/null 2>&1
check "--adopt es idempotente y conserva AGENTS.md y GLOBAL_STATE.md existentes" 'cmp -s "$BROWN/GLOBAL_STATE.md" "$WORK/gs.adopt.bak" && grep -q "custom-agents" "$BROWN/AGENTS.md"'

# ------------------------------------------------------------------------------
section "task.sh archive y métricas con archivo"
new_project archive_test
# Plantilla trae TASK-001 y TASK-002; añadimos TASK-003 y TASK-004
$T add "Tercera tarea" backend-agent "c3" >/dev/null
$T add "Cuarta tarea" backend-agent "c4" >/dev/null

# Dejar TASK-001 en IN_PROGRESS (no debe archivarse) y cerrar TASK-002, TASK-003 (1/3), TASK-004
$T start TASK-001 >/dev/null 2>&1
git checkout -q main

for tid in TASK-002 TASK-003 TASK-004; do
  $T start "$tid" >/dev/null 2>&1
  echo "// $tid" >> "work_$tid.ts"
  git add "work_$tid.ts"
  $T commit "$tid" "implementar $tid" >/dev/null 2>&1
  $T handoff "$tid" --verify "true" >/dev/null 2>&1
  if [ "$tid" = "TASK-003" ]; then
    $T reject "$tid" "falta edge case" >/dev/null 2>&1
    $T start "$tid" >/dev/null 2>&1
    $T handoff "$tid" --verify "true" >/dev/null 2>&1
    $T learn "Leccion archivo $tid" backend "causa $tid" "solucion $tid" >/dev/null 2>&1
    LAST_LL=$(awk -F'|' '/^\|/ { c=$2; gsub(/[ \t`]/,"",c); if (c~/^LL-[0-9]+$/) last=c } END { print last }' .agents/brain/lessons_learned.md)
  fi
  cat > ".agents/reviews/qa_${tid}.md" <<EOF_REV
- **Revisor**: \`qa-security-agent\`
- **Veredicto**: \`APROBADO\`
EOF_REV
  if [ "$tid" = "TASK-003" ]; then
    $T close "$tid" --lesson "$LAST_LL" >/dev/null 2>&1
  else
    $T close "$tid" >/dev/null 2>&1
  fi
  BR=$(git branch --show-current)
  git checkout -q main
  git merge --no-ff -q "$BR" -m "chore($tid): merge" --no-verify
  git branch -d -q "$BR"
done

ARCH_RES=$($T archive --keep 1 --phase "Fase 1 Base" 2>&1)
check "task.sh archive mueve 2 DONE más antiguas y conserva 1 DONE + activas" '[ "$(col TASK-002 5)" = "" ] && [ "$(col TASK-003 5)" = "" ] && [ "$(col TASK-004 5)" = "DONE" ] && [ "$(col TASK-001 5)" = "IN_PROGRESS" ] && grep -q "TASK-002" .agents/archive/tasks_*.md && grep -q "TASK-003" .agents/archive/tasks_*.md && printf "%s" "$ARCH_RES" | grep -q "Archivadas 2 tareas"'
check "task.sh metrics incluye tareas DONE archivadas y rechazos QA" 'MET=$($T metrics) && printf "%s" "$MET" | grep -q "DONE:.*3 (1 activas, 2 archivadas)" && printf "%s" "$MET" | grep -q "3 de 4 tareas" && printf "%s" "$MET" | grep -q "1/3 → 1"'
check "validate-state.sh contabiliza archivadas sin falsos errores" 'VAL=$(bash ./.agents/scripts/validate-state.sh 2>&1) && printf "%s" "$VAL" | grep -q "3 (1 activas, 2 archivadas)"'
check "require_task distingue una tarea archivada de una inexistente" '! $T start TASK-002 2>&1 | grep -q "no existe" && $T start TASK-002 2>&1 | grep -q "archivada"'

# Archivar la DONE restante (TASK-004, ID máximo) y probar que add no reutiliza IDs archivados
$T archive --keep 0 >/dev/null 2>&1
check "task.sh archive --keep 0 archiva la DONE restante en archivo existente del día" '[ "$(col TASK-004 5)" = "" ] && grep -q "TASK-004" .agents/archive/tasks_*.md'
check "next_id tras archive no reutiliza IDs archivados" '$T add "Quinta tarea" frontend-agent "c5" >/dev/null && [ "$(col TASK-005 4)" = "frontend-agent" ]'

# Simular ID duplicado entre GLOBAL_STATE.md y .agents/archive/
cp GLOBAL_STATE.md "$WORK/gs.predup"
printf '| `TASK-002` | Duplicada | `backend-agent` | `DONE` | `0/3` | ok |\n' >> GLOBAL_STATE.md
check "validate-state.sh detecta TASK-XXX duplicada entre tablero y archivo" '! bash ./.agents/scripts/validate-state.sh >/dev/null 2>&1'
cp "$WORK/gs.predup" GLOBAL_STATE.md

printf "\nResultado: %d OK, %d fallidas\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
