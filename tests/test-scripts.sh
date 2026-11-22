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
check ".mcp.json y plugin MCP de Antigravity instalados" '[ -f .mcp.json ] && grep -q "skill-maestro" .mcp.json && [ -f .agents/mcp/server.mjs ] && [ -x .agents/mcp/server.mjs ] && [ -f .agents/plugins/maestro-mcp/mcp_config.json ]'
check "servidor MCP nativo pasa suite de pruebas (test-mcp.mjs)" 'node --test "$ROOT/tests/test-mcp.mjs" >/dev/null'
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

bash "$ROOT/.agents/scripts/init-project.sh" "Mi Nuxt App" "$WORK/nuxt-app" --stack nuxt >/dev/null 2>&1
check "init-project con --stack nuxt pre-configura GLOBAL_STATE.md" 'grep -q "stack-vue-nuxt-postgres" "$WORK/nuxt-app/GLOBAL_STATE.md" && grep -q "Nitro" "$WORK/nuxt-app/GLOBAL_STATE.md"'

bash "$ROOT/.agents/scripts/init-project.sh" "Mi React Vite App" "$WORK/react-vite-app" --stack react-vite >/dev/null 2>&1
check "init-project con --stack react-vite pre-configura GLOBAL_STATE.md" 'grep -q "stack-react-vite-node" "$WORK/react-vite-app/GLOBAL_STATE.md" && grep -q "TanStack" "$WORK/react-vite-app/GLOBAL_STATE.md"'

bash "$ROOT/.agents/scripts/init-project.sh" "Mi NestJS API" "$WORK/nestjs-app" --stack nestjs >/dev/null 2>&1
check "init-project con --stack nestjs pre-configura GLOBAL_STATE.md" 'grep -q "stack-nestjs-postgres" "$WORK/nestjs-app/GLOBAL_STATE.md" && grep -q "ValidationPipe" "$WORK/nestjs-app/GLOBAL_STATE.md"'

for st in nextjs angular fastapi nuxt react-vite nestjs; do
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
check "init-project.sh muestra el banner con nombre y creador" 'OUT=$(bash "$ROOT/.agents/scripts/init-project.sh" "Banner Test" "$WORK/banner-app"); printf "%s" "$OUT" | grep -q "SKILL MAESTRO" && printf "%s" "$OUT" | grep -q "Klisman Vizcarra"'
check "welcome_cover_template.html existe e init-project lo instala" '[ -f "$ROOT/.agents/templates/welcome_cover_template.html" ] && [ -f "$WORK/banner-app/.agents/templates/welcome_cover_template.html" ]'
check "init-project.sh --lang en genera GLOBAL_STATE y AGENTS en ingles" 'bash "$ROOT/.agents/scripts/init-project.sh" "English App" "$WORK/en-app" --lang en >/dev/null && grep -q "Single Source of Truth" "$WORK/en-app/GLOBAL_STATE.md" && grep -q "Golden Rule" "$WORK/en-app/AGENTS.md"'
check "init-project.sh --lang con idioma invalido falla con exit 1" '! bash "$ROOT/.agents/scripts/init-project.sh" "Bad Lang" "$WORK/bad-lang-app" --lang it >/dev/null 2>&1'
check "package.json es valido y define el binario skill-maestro" 'node -e "const pkg = JSON.parse(require(\"fs\").readFileSync(\"$ROOT/package.json\")); if (pkg.name !== \"skill-maestro\" || !pkg.bin[\"skill-maestro\"]) process.exit(1);"'
check "bin/skill-maestro.js --help muestra el banner y comandos disponibles" 'OUT=$(node "$ROOT/bin/skill-maestro.js" --help); printf "%s" "$OUT" | grep -q "SKILL MAESTRO" && printf "%s" "$OUT" | grep -q "Klisman Vizcarra" && printf "%s" "$OUT" | grep -q "serve"'
check "bin/skill-maestro.js --version muestra la version de skill-maestro" 'OUT=$(node "$ROOT/bin/skill-maestro.js" --version); printf "%s" "$OUT" | grep -q "skill-maestro v"'

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
grep "LL-001" "$WORK/ll.doc" >> .agents/brain/lessons_learned.md
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
grep "| \`TASK-001\`" "$WORK/gs_dup.bak" >> GLOBAL_STATE.md
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
check "normaliza '..': docs/../server/auth/z.ts recibe la lección de server/auth" 'ctx_text s8b "$PWD/docs/../server/auth/z.ts" | grep -q "LL-003"'
check "una ruta con '..' que sale del proyecto se ignora" '[ -z "$(ctx s8c "$PWD/../fuera/server/auth/z.ts")" ]'
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
check "'.agents/../src/app.ts' no esquiva el bloqueo (ruta normalizada)" 'edit_json "$PWD/.agents/../src/app.ts" | CLAUDE_PROJECT_DIR="$PWD" bash $H 2>/dev/null; [ $? -eq 2 ]'
check "'docs/./../src/app.ts' tampoco esquiva el bloqueo" 'edit_json "$PWD/docs/./../src/app.ts" | CLAUDE_PROJECT_DIR="$PWD" bash $H 2>/dev/null; [ $? -eq 2 ]'
check "una ruta relativa del proyecto se controla (src/app.ts bloqueada)" 'edit_json "src/app.ts" | CLAUDE_PROJECT_DIR="$PWD" bash $H 2>/dev/null; [ $? -eq 2 ]'
check "una ruta relativa fuera del proyecto (../otro/x.ts) se permite" 'edit_json "../otro/x.ts" | CLAUDE_PROJECT_DIR="$PWD" bash $H'
check "una ruta absoluta que sale del proyecto con '..' se permite" 'edit_json "$PWD/../otro/x.ts" | CLAUDE_PROJECT_DIR="$PWD" bash $H'
ln -s "$PWD" "$WORK/enlace-hook"
check "la misma ruta vista a través de un symlink del proyecto sigue bloqueada" 'edit_json "$WORK/enlace-hook/src/app.ts" | CLAUDE_PROJECT_DIR="$PWD" bash $H 2>/dev/null; [ $? -eq 2 ] && edit_json "$PWD/src/app.ts" | CLAUDE_PROJECT_DIR="$WORK/enlace-hook" bash $H 2>/dev/null; [ $? -eq 2 ]'
check "un file_path que no es texto se bloquea (fail-closed)" 'printf "{\"tool_input\":{\"file_path\":123}}" | CLAUDE_PROJECT_DIR="$PWD" bash $H 2>/dev/null; [ $? -eq 2 ]'
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
check "run_claude clean_env preserva ANTHROPIC_API_KEY si se especifica" 'python3 -c "import sys; sys.path.insert(0, \"$ROOT/tests/triggers\"); import run_claude; env = run_claude.clean_env(\"sk-test\"); assert env.get(\"ANTHROPIC_API_KEY\") == \"sk-test\", env"'
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

# Presupuesto del listado de skills de Claude Code (TASK-081): tope por skill y total
run_desc_budget() {  # run_desc_budget <caracteres> <n skills> [plain|reordered|folded|broken]
  local per="$1" count="$2" form="${3:-plain}"
  local fake; fake="$(mktemp -d "$WORK/budget.XXXXXX")"
  local cases="$fake/cases.json" i n filler desc
  filler="$(printf 'x%.0s' $(seq 1 $((per > 12 ? per : 12))))"
  printf '{"cases": [' > "$cases"
  for i in $(seq 1 "$count"); do
    n="skill-presupuesto-$i"
    mkdir -p "$fake/skills/$n"
    desc="Usar cuando ${filler:0:$((per > 12 ? per - 12 : 0))}"
    case "$form" in
      reordered) printf -- '---\ndescription: %s\nname: %s\nallowed-tools: Read\n---\n# %s\n' "$desc" "$n" "$n" ;;
      folded)    printf -- '---\nname: %s\ndescription: >\n  %s\n  y una segunda linea\n---\n# %s\n' "$n" "$desc" "$n" ;;
      broken)    printf -- '---\nname: %s\n---\n# %s\n' "$n" "$n" ;;
      *)         printf -- '---\nname: %s\ndescription: %s\n---\n# %s\n' "$n" "$desc" "$n" ;;
    esac > "$fake/skills/$n/SKILL.md"
    [ "$i" -gt 1 ] && printf ',' >> "$cases"
    printf '{"id":"b-%s-1","prompt":"p","expect":["%s"]},{"id":"b-%s-2","prompt":"p","expect":["%s"]}' "$i" "$n" "$i" "$n" >> "$cases"
  done
  printf ']}\n' >> "$cases"
  python3 "$ROOT/tests/triggers/lint_descriptions.py" --skills-dir "$fake/skills" --cases "$cases" --threshold 1.1 2>&1
}
check "lint_descriptions.py acepta descripciones dentro del presupuesto (300 c/u, total <= 15000)" 'run_desc_budget 300 2 >/dev/null'
check "lint_descriptions.py rechaza una descripción de más de 300 caracteres" '! run_desc_budget 301 1 >/dev/null && run_desc_budget 301 1 2>&1 | grep -q "301 caracteres (máximo 300)"'
check "lint_descriptions.py rechaza descripciones que suman más de 15000 caracteres" '! run_desc_budget 300 51 >/dev/null && run_desc_budget 300 51 2>&1 | grep -q "suman 15300 caracteres (máximo 15000)"'
check "lint_descriptions.py mide descripciones con claves en otro orden o multilínea (BUG-TASK-081-1)" '! run_desc_budget 301 1 reordered >/dev/null && run_desc_budget 301 1 reordered 2>&1 | grep -q "301 caracteres (máximo 300)" && run_desc_budget 301 1 folded 2>&1 | grep -q "caracteres (máximo 300)"'
check "lint_descriptions.py falla con una SKILL.md sin description legible" '! run_desc_budget 0 1 broken >/dev/null && run_desc_budget 0 1 broken 2>&1 | grep -q "frontmatter sin name o description legibles"'
check "las skills reales caben en el presupuesto del listado de Claude Code" 'python3 "$ROOT/tests/triggers/lint_descriptions.py" | grep -qE "Presupuesto de descripciones: [0-9]+/15000" && ! python3 "$ROOT/tests/triggers/lint_descriptions.py" | grep -q "caracteres (máximo"'
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
assert len(evals) >= 21, f"se esperaban >=21 evals, hay {len(evals)}"
ids = [ev["id"] for ev in evals]
assert len(ids) == len(set(ids)), "ids de eval duplicados"
for ev in evals:
    assert (root / ".agents/skills" / ev["skill"] / "SKILL.md").is_file(), ev["skill"]
    assert ev.get("checks"), ev["id"]
    scripts = ev.get("setup", "") + " ".join(c for _, c in ev["checks"])
    for fx in re.findall(r"\$FIXTURES/([A-Za-z0-9_.-]+)", scripts):
        f = root / "tests/evals/fixtures" / fx
        assert f.is_file(), fx
        assert f.stat().st_mode & 0o777 == 0o755, f"{fx} debe tener permisos 755"
covered = {ev["skill"] for ev in evals}
for s in ["backend-agent", "frontend-agent", "database-architect-agent", "domain-logic-agent", "devops-cloud-agent", "testing-strategy", "async-jobs", "research-agent", "crear-plan", "adoptar-proyecto", "resilience-engineering", "accessibility-testing", "finops-cost-optimization"]:
    assert s in covered, f"falta una eval de {s}"
PY'

check "run_evals.py --verify-baselines: todas las evals fallan en el estado inicial (FAIL_INIT, sin LLM)" 'python3 "$ROOT/tests/evals/run_evals.py" --verify-baselines --jobs 4 >/dev/null 2>&1'
printf '%s\n' '{"evals":[{"id":"no-mide","skill":"aprender","setup":"true","prompt":"x","checks":[["siempre pasa","true"]]}]}' > "$WORK/evals-nomide.json"
check "--verify-baselines falla si una eval pasa sin que la skill haga nada" '! python3 "$ROOT/tests/evals/run_evals.py" --verify-baselines --file "$WORK/evals-nomide.json" >/dev/null 2>&1'
printf '%s\n' '{"evals":[{"id":"setup-roto","skill":"aprender","setup":"exit 3","prompt":"x","checks":[["falla","false"]]}]}' > "$WORK/evals-setup.json"
check "--verify-baselines falla si el setup de una eval falla" '! python3 "$ROOT/tests/evals/run_evals.py" --verify-baselines --file "$WORK/evals-setup.json" >/dev/null 2>&1'
check "--verify-baselines con --only inexistente falla" '! python3 "$ROOT/tests/evals/run_evals.py" --verify-baselines --only no-existe >/dev/null 2>&1'
printf '%s\n' '{"evals":[{"id":"sin-herramienta","skill":"aprender","setup":"true","prompt":"x","checks":[["usa una herramienta que no existe","herramienta-que-no-existe-xyz --version"],["pasa","true"]]}]}' > "$WORK/evals-127.json"
check "--verify-baselines trata un check con exit 127 como error del entorno, no como FAIL_INIT" '! python3 "$ROOT/tests/evals/run_evals.py" --verify-baselines --file "$WORK/evals-127.json" >/dev/null 2>&1 && python3 "$ROOT/tests/evals/run_evals.py" --verify-baselines --file "$WORK/evals-127.json" 2>&1 | grep -q "exit 127"'
mkdir -p "$WORK/tmp-evals"
check "si git falla al preparar el proyecto, no quedan temporales skill-eval-* huérfanos" 'PY3=$(command -v python3); env -i PATH=/nonexistent HOME="$HOME" TMPDIR="$WORK/tmp-evals" "$PY3" "$ROOT/tests/evals/run_evals.py" --verify-baselines --only qa-reject-idor >/dev/null 2>&1; [ -z "$(ls -A "$WORK/tmp-evals")" ]'

# TD-005: soluciones correctas que las evals rechazaban (y las trampas siguen fallando)
eval_check() {  # eval_check <id> <prefijo del nombre del check> <directorio>
  local script
  script=$(python3 - "$ROOT/tests/evals/evals.json" "$1" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
evs = d if isinstance(d, list) else d["evals"]
ev = next(e for e in evs if e["id"] == sys.argv[2])
print(next(s for n, s in ev["checks"] if n.startswith(sys.argv[3])))
PY
)
  (cd "$3" && bash -c "$script" >/dev/null 2>&1)
}
D="$WORK/td005-docker"; mkdir -p "$D"
printf '%s\n' 'FROM node:24 AS build' 'RUN npm ci' 'FROM node:24-slim' '# JWT_SECRET se inyecta en tiempo de ejecucion, nunca aqui' 'USER node' > "$D/Dockerfile"
check "devops: un comentario que menciona JWT_SECRET no cuenta como secreto" 'eval_check devops-docker-no-root "sin secretos" "$D"'
printf '%s\n' 'FROM node:24 AS build' 'FROM node:24-slim' 'ENV JWT_SECRET=x' 'USER node' > "$D/Dockerfile"
check "devops: un ENV JWT_SECRET sigue fallando" '! eval_check devops-docker-no-root "sin secretos" "$D"'
if command -v node >/dev/null 2>&1; then
  C="$WORK/td005-clock"; mkdir -p "$C/src" "$C/test"
  printf '%s\n' '{ "name": "x", "type": "module" }' > "$C/package.json"
  printf '%s\n' "export const TTL_MS = 15 * 60 * 1000;" \
    "export function createLink(userId, { now = Date.now, newId = () => Math.random().toString(36).slice(2) } = {}) { return { token: newId(), userId, expiresAt: now() + TTL_MS }; }" \
    "export function isExpired(link, { now = Date.now } = {}) { return now() >= link.expiresAt; }" \
    "export const describeTtl = () => '15 min';" > "$C/src/links.js"
  printf '%s\n' "export const fixedClock = (t) => () => t;" > "$C/src/clock.js"
  printf '%s\n' "import { test } from 'node:test';" "import assert from 'node:assert/strict';" \
    "import { createLink, isExpired, TTL_MS, describeTtl } from '../src/links.js';" "import { fixedClock } from '../src/clock.js';" \
    "const T0 = new Date('2026-01-01T00:00:00Z').getTime();" \
    "test('caduca justo en expiresAt', () => { const l = createLink('u', { now: fixedClock(T0), newId: () => 'a' }); assert.equal(isExpired(l, { now: fixedClock(T0 + TTL_MS) }), true); assert.equal(isExpired(l, { now: fixedClock(T0 + TTL_MS - 1) }), false); });" \
    "test('ttl', () => assert.equal(describeTtl(), '15 min'));" > "$C/test/links.test.js"
  check "testing: new Date con fecha fija en los tests ya no se rechaza" 'eval_check testing-reloj-determinista "los tests no usan el reloj real" "$C"'
  check "testing: el mutante acepta módulos auxiliares en src/ y exports nuevos" 'eval_check testing-reloj-determinista "los tests pasan con una implementacion correcta" "$C"'
  printf '%s\n' "import { test } from 'node:test';" "test('x', () => { const n = new Date(); });" > "$C/test/extra.test.js"
  check "testing: new Date() sin argumentos en los tests sigue fallando" '! eval_check testing-reloj-determinista "los tests no usan el reloj real" "$C"'
  rm -f "$C/test/extra.test.js"
  sed -i.bak 's/fixedClock(T0 + TTL_MS) }), true/fixedClock(T0 + TTL_MS + 1) }), true/' "$C/test/links.test.js"
  check "testing: tests que no cubren el límite exacto siguen fallando el mutante" '! eval_check testing-reloj-determinista "los tests pasan con una implementacion correcta" "$C"'
  W="$WORK/td005-worker"; mkdir -p "$W/src"
  printf '%s\n' '{ "name": "x", "type": "module" }' > "$W/package.json"
  printf '%s\n' "const TRANSIENT = new Set(['ECONNRESET', 'ETIMEDOUT', 'EAI_AGAIN']);" \
    "export function computeBackoff(attempt, random = Math.random) { const base = Math.min(1000 * 2 ** (attempt - 1), 3600000); return Math.floor(base / 2 + random() * base / 2); }" \
    "export async function handleMessage(msg, deps) {" \
    "  if (await deps.store.has(msg.id)) return;" \
    "  try { await deps.mailer.send(msg.to, msg.template); } catch (err) {" \
    "    if (!TRANSIENT.has(err.code) || msg.attempt >= deps.maxAttempts) { deps.queue.deadLetter(msg, err); return; }" \
    "    deps.queue.retry({ ...msg, attempt: msg.attempt + 1 }, computeBackoff(msg.attempt)); return; }" \
    "  await deps.store.add(msg.id);" "}" > "$W/src/worker.js"
  check "async: clasificar los fallos transitorios por err.code ya no se rechaza" 'eval_check async-worker-idempotente "fallo transitorio" "$W" && eval_check async-worker-idempotente "deduplica" "$W"'
  sed -i.bak 's/  await deps.store.add(msg.id);//; s/if (await deps.store.has(msg.id)) return;/if (await deps.store.has(msg.id)) return; await deps.store.add(msg.id);/' "$W/src/worker.js"
  check "async: marcar como enviado antes de enviar sigue fallando" '! eval_check async-worker-idempotente "deduplica" "$W"'
  printf '%s\n' "export function computeBackoff(attempt, random = Math.random) { const base = Math.min(1000 * 2 ** (attempt - 1), 3600000); return Math.floor(base / 2 + random() * base / 2); }" \
    "export async function handleMessage(msg, deps) {" \
    "  if (await deps.store.has(msg.id)) return;" \
    "  try { await deps.mailer.send(msg.to, msg.template); } catch (err) {" \
    "    if (err.code === 'ECONNRESET') { if (msg.attempt >= deps.maxAttempts) deps.queue.deadLetter(msg, err); else deps.queue.retry({ ...msg, attempt: msg.attempt + 1 }, computeBackoff(msg.attempt)); return; }" \
    "    console.error(err.message); }" \
    "  await deps.store.add(msg.id);" "}" > "$W/src/worker.js"
  check "async: un error sin code que marca el email como enviado sigue fallando" '! eval_check async-worker-idempotente "deduplica" "$W"'
else
  printf "  ⚠️  sin node: se omiten las comprobaciones de TD-005 que ejecutan JavaScript\n"
fi

# TASK-083: matriz de soluciones de las evals de resiliencia, accesibilidad y FinOps (LL-017)
# La referencia de tests/evals/solutions/ debe pasar cada check; cada trampa debe hacer fallar el suyo.
export FIXTURES="$ROOT/tests/evals/fixtures"
SOL="$ROOT/tests/evals/solutions"
sol_trap() {  # sol_trap <eval> <prefijo del check> <archivo> <sustitución perl>: 0 si la trampa se detecta
  local d; d="$(mktemp -d "$WORK/sol.XXXXXX")"
  cp -R "$SOL/$1/." "$d/"
  perl -0pi -e "$4" "$d/$3"
  cmp -s "$SOL/$1/$3" "$d/$3" && return 1   # la sustitución no cambió nada: la trampa no se aplicó
  ! eval_check "$1" "$2" "$d"
}
sol_ok() {  # sol_ok <eval> <prefijo del check> [archivo] [sustitución perl]: 0 si la solución (o su variante) pasa
  local d; d="$(mktemp -d "$WORK/sol.XXXXXX")"
  cp -R "$SOL/$1/." "$d/"
  if [ -n "${3:-}" ]; then
    perl -0pi -e "$4" "$d/$3"
    cmp -s "$SOL/$1/$3" "$d/$3" && return 1   # la variante no se aplicó: no prueba nada
  fi
  eval_check "$1" "$2" "$d"
}
F=finops-rightsizing-logs
check "finops: la referencia pasa los 4 checks de contenido" 'sol_ok $F "thumbnail" && sol_ok $F "app-logs" && sol_ok $F "consulta" && sol_ok $F "el informe"'
check "finops: alternativas correctas (256 MB, BETWEEN, ahorro en formato inglés)" 'sol_ok $F thumbnail infra/functions.json "s/\"memoryMb\": 512/\"memoryMb\": 256/" && sol_ok $F consulta analytics/daily_revenue.sql "s/event_date = DATE_SUB\(CURRENT_DATE\(\), INTERVAL 1 DAY\)/event_date BETWEEN DATE \"2026-11-19\" AND DATE \"2026-11-19\"/" && sol_ok $F "el informe" docs/finops/report.md "s/32,50 USD/USD 32.50/"'
check "finops: trampas de memoria y timeout (128 MB, sin tocar, timeout 900 s)" 'sol_trap $F thumbnail infra/functions.json "s/\"memoryMb\": 512/\"memoryMb\": 128/" && sol_trap $F thumbnail infra/functions.json "s/\"memoryMb\": 512/\"memoryMb\": 3008/" && sol_trap $F thumbnail infra/functions.json "s/\"timeoutS\": 10/\"timeoutS\": 900/"'
check "finops: trampas de ciclo de vida (borrar a 30 días, mover el día 0, sin expiración)" 'sol_trap $F app-logs infra/storage.json "s/\"expirationDays\": 365/\"expirationDays\": 30/" && sol_trap $F app-logs infra/storage.json "s/\"days\": 30,/\"days\": 0,/" && sol_trap $F app-logs infra/storage.json "s/, \"expirationDays\": 365//"'
check "finops: trampas de consulta (SELECT *, partición solo en un comentario)" 'sol_trap $F consulta analytics/daily_revenue.sql "s/SELECT SUM\(amount_cents\) \/ 100 AS revenue/SELECT */" && sol_trap $F consulta analytics/daily_revenue.sql "s/WHERE event_date = DATE_SUB\(CURRENT_DATE\(\), INTERVAL 1 DAY\)\n  AND /-- event_date\nWHERE /"'
check "finops: trampas del informe (MB sin pasar a GB, cifra inventada)" 'sol_trap $F "el informe" docs/finops/report.md "s/32,50/33280,00/" && sol_trap $F "el informe" docs/finops/report.md "s/32,50/120,00/"'
A=accessibility-wcag-formulario
check "a11y: la referencia cumple WCAG y sus tests detectan cada violación reintroducida" 'sol_ok $A "signup.html cumple" && sol_ok $A "los tests fallan si se reintroduce"'
check "a11y: alternativas correctas (label envolvente, role=presentation, input submit, hex corto)" 'sol_ok $A "signup.html cumple" public/signup.html "s/<label for=\"email\">Email<\/label>\n\s*<input type=\"email\" id=\"email\" name=\"email\" autocomplete=\"email\">/<label>Email <input type=\"email\" id=\"email\" name=\"email\"><\/label>/" && sol_ok $A "signup.html cumple" public/signup.html "s/src=\"divider.png\" alt=\"\"/src=\"divider.png\" role=\"presentation\"/" && sol_ok $A "signup.html cumple" public/signup.html "s/<button type=\"submit\" class=\"btn\">Crear cuenta<\/button>/<input type=\"submit\" value=\"Crear cuenta\" class=\"btn\">/" && sol_ok $A "signup.html cumple" public/signup.html "s/#595959/#555/"'
check "a11y: trampas (solo placeholder, alt con nombre de archivo, div role=button, contraste #888, salto h1-h3)" 'sol_trap $A "signup.html cumple" public/signup.html "s/<label for=\"email\">Email<\/label>\n\s*<input type=\"email\" id=\"email\"/<input type=\"email\" id=\"email\" placeholder=\"Email\"/" && sol_trap $A "signup.html cumple" public/signup.html "s/alt=\"Acme\"/alt=\"logo.png\"/" && sol_trap $A "signup.html cumple" public/signup.html "s/<button type=\"submit\" class=\"btn\">Crear cuenta<\/button>/<div class=\"btn\" role=\"button\" tabindex=\"0\" onclick=\"x()\">Crear cuenta<\/div>/" && sol_trap $A "signup.html cumple" public/signup.html "s/#595959/#888888/" && sol_trap $A "signup.html cumple" public/signup.html "s/<h2>Datos de acceso<\/h2>/<h3>Datos de acceso<\/h3>/"'
check "a11y: tests que no comprueban el contraste no pasan el check de mutantes" 'sol_trap $A "los tests fallan si se reintroduce" test/a11y.test.js "s/^test\(.contraste hint.*\n//m"'
# BUG-TASK-083-1: casos del revisor (variantes correctas que se rechazaban y trampas que pasaban)
check "a11y: acepta label envolvente sin id, selector agrupado con rgb() y color de .hint en línea" 'sol_ok $A "signup.html cumple" public/signup.html "s/<label for=\"email\">Email<\/label>\n\s*<input type=\"email\" id=\"email\" name=\"email\" autocomplete=\"email\">/<label>Correo <input type=\"email\" name=\"email\"><\/label>/" && sol_ok $A "signup.html cumple" public/signup.html "s/\.hint \{ color: #595959;/.hint, .note { color: rgb(118, 118, 118);/" && sol_ok $A "signup.html cumple" public/signup.html "s/\.hint \{ color: #595959; font-size: 0.9rem; \}/.hint { font-size: 0.9rem; }/; s/<p class=\"hint\" id=\"password-hint\">/<p class=\"hint\" id=\"password-hint\" style=\"color: #595959\">/"'
check "a11y: el mutante de contraste también cubre selectores agrupados y rgb()" 'sol_ok $A "los tests fallan si se reintroduce" public/signup.html "s/\.hint \{ color: #595959;/.hint, .note { color: rgb(89, 89, 89);/" '
check "a11y: rechaza label oculto (en línea o por clase), .hint sobrescrito, alt \"imagen del logo\" y #777777" 'sol_trap $A "signup.html cumple" public/signup.html "s/<label for=\"email\">/<label for=\"email\" style=\"display: none\">/" && sol_trap $A "signup.html cumple" public/signup.html "s/<label for=\"email\">/<label for=\"email\" class=\"oculto\">/; s/<\/style>/  .oculto { display:none }\n<\/style>/" && sol_trap $A "signup.html cumple" public/signup.html "s/<\/style>/  form p.hint { color: #aaaaaa; }\n<\/style>/" && sol_trap $A "signup.html cumple" public/signup.html "s/alt=\"Acme\"/alt=\"imagen del logo\"/" && sol_trap $A "signup.html cumple" public/signup.html "s/#595959/#777777/"'
check "finops: rechaza event_date solo en GROUP BY, en una subconsulta o en un comentario, y SELECT DISTINCT *" 'sol_trap $F consulta analytics/daily_revenue.sql "s/.*/SELECT e.event_date, SUM(e.amount_cents) AS revenue FROM analytics.events e WHERE e.event_type = \x27purchase\x27 GROUP BY e.event_date;\n/s" && sol_trap $F consulta analytics/daily_revenue.sql "s/.*/SELECT SUM(amount_cents) AS revenue FROM analytics.events WHERE event_type = \x27purchase\x27 AND user_id IN (SELECT user_id FROM analytics.events WHERE event_date = CURRENT_DATE());\n/s" && sol_trap $F consulta analytics/daily_revenue.sql "s/.*/SELECT SUM(amount_cents) AS revenue FROM analytics.events WHERE \/* event_date = ayer *\/ event_type = \x27purchase\x27;\n/s" && sol_trap $F consulta analytics/daily_revenue.sql "s/SELECT SUM\(amount_cents\) \/ 100 AS revenue/SELECT DISTINCT */"'
check "finops: acepta CTE, alias con BETWEEN, condición entre paréntesis y ahorro en una tabla" 'sol_ok $F consulta analytics/daily_revenue.sql "s/.*/WITH ayer AS (SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) AS d)\nSELECT SUM(amount_cents) AS revenue FROM analytics.events, ayer WHERE event_date = ayer.d AND event_type = \x27purchase\x27;\n/s" && sol_ok $F consulta analytics/daily_revenue.sql "s/.*/SELECT SUM(e.amount_cents) AS revenue FROM analytics.events AS e WHERE (e.event_date BETWEEN DATE \x272026-11-19\x27 AND DATE \x272026-11-19\x27) AND e.event_type = \x27purchase\x27 GROUP BY e.event_type;\n/s" && sol_ok $F "el informe" docs/finops/report.md "s/.*/# Informe\n\n| Función | Antes | Después | Ahorro mensual |\n| :- | :- | :- | :- |\n| thumbnail | 39,17 USD | 6,67 USD | 32,50 USD |\n/s"'
check "finops: el informe no acepta una cifra casual que no es un importe (\"día 35\")" 'sol_trap $F "el informe" docs/finops/report.md "s/.*/# Informe\nAhorro mensual: 59,79 USD (calculado con p95). Revisión el día 32.\n/s"'
if command -v node >/dev/null 2>&1; then
  R=resilience-pagos-breaker
  check "resiliencia: la referencia pasa timeout, reintentos, backoff, breaker y mutantes" 'sol_ok $R "timeout" && sol_ok $R "reintenta solo" && sol_ok $R "backoff" && sol_ok $R "circuit breaker" && sol_ok $R "los tests del proyecto"'
  check "resiliencia: alternativa correcta (equal jitter) pasa el backoff" 'sol_ok $R backoff src/resilient.js "s/Math.floor\(random\(\) \* Math.min\(maxDelayMs, baseDelayMs \* 2 \*\* \(n - 1\)\)\)/(c => Math.floor(c \/ 2 + random() * c \/ 2))(Math.min(maxDelayMs, baseDelayMs * 2 ** (n - 1)))/"'
  check "resiliencia: trampas de reintento (reintentar un 400) y timeout (sin timeout)" 'sol_trap $R "reintenta solo" src/resilient.js "s/if \(!isTransient\(e\)\) \{ if \(trial\) state = .CLOSED.; throw e; \}//" && sol_trap $R timeout src/resilient.js "s/const t = setTimeout\(\(\) => reject\(Object.assign\(new Error\(.timeout.\), \{ code: .ETIMEDOUT. \}\)\), timeoutMs\);/const t = 0;/"'
  check "resiliencia: trampas de backoff (fijo, sin jitter, sin tope)" 'sol_trap $R backoff src/resilient.js "s/Math.min\(maxDelayMs, baseDelayMs \* 2 \*\* \(n - 1\)\)/baseDelayMs/" && sol_trap $R backoff src/resilient.js "s/Math.floor\(random\(\) \* /Math.floor(1 * /" && sol_trap $R backoff src/resilient.js "s/Math.min\(maxDelayMs, baseDelayMs \* 2 \*\* \(n - 1\)\)/(baseDelayMs * 2 ** (n - 1))/"'
  check "resiliencia: trampas de breaker (fallos totales, nunca medio abre, 4xx abre)" 'sol_trap $R "circuit breaker" src/resilient.js "s/failures = 0; state = .CLOSED.;/state = \"CLOSED\";/" && sol_trap $R "circuit breaker" src/resilient.js "s/state = .HALF_OPEN.;/throw Object.assign(new Error(\"open\"), { code: \"CIRCUIT_OPEN\" });/" && sol_trap $R "circuit breaker" src/resilient.js "s/if \(!isTransient\(e\)\) \{ if \(trial\) state = .CLOSED.; throw e; \}/if (!isTransient(e)) { failures++; if (failures >= failureThreshold) { state = \"OPEN\"; openedAt = now(); } throw e; }/"'
  check "resiliencia: tests sin caso de breaker no pasan el check de mutantes" 'sol_trap $R "los tests del proyecto" test/resilient.test.js "s/^test\(.breaker.*//ms"'
  check "resiliencia: rechaza breaker que cuenta intentos, HALF_OPEN que deja pasar todo y no reintentar ECONNREFUSED" 'sol_trap $R "circuit breaker" src/resilient.js "s/if \(!trial && attempt < maxRetries\) \{ await sleep/if (!trial && attempt < maxRetries) { failures++; await sleep/" && sol_trap $R "circuit breaker" src/resilient.js "s/^\s*if \(state === .HALF_OPEN.\) throw circuitOpen\(\);.*\n//m" && sol_trap $R "reintenta solo" src/resilient.js "s/.ECONNRESET., .ECONNREFUSED./\x27ECONNRESET\x27/"'
  check "resiliencia: rechaza un timeout global de la llamada en lugar de uno por intento" 'sol_trap $R timeout src/resilient.js "s/async call\(fn\) \{/async call(fn) { return withTimeout(() => this.inner(fn)); },\n    async inner(fn) {/; s/const v = await withTimeout\(fn\);/const v = await fn();/"'
  check "resiliencia: el check de mutantes no deja temporales aunque falle (BUG-TASK-083-1)" 'TD=$(mktemp -d "$WORK/mut.XXXXXX"); d=$(mktemp -d "$WORK/sol.XXXXXX"); cp -R "$SOL/$R/." "$d/"; printf "%s\n" "import { test } from \"node:test\"; test(\"x\", () => {});" > "$d/test/resilient.test.js"; (cd "$d" && TMPDIR="$TD" node "$FIXTURES/resilience_checks.mjs" mutants >/dev/null 2>&1); r=$?; [ "$r" -ne 0 ] && [ -z "$(ls -A "$TD")" ]'
else
  printf "  ⚠️  sin node: se omiten las comprobaciones de TASK-083 que ejecutan JavaScript\n"
fi

# ------------------------------------------------------------------------------
section "task.sh check / pre-edit-check.sh (paridad Antigravity)"
new_project precheck
mkdir -p src
check "check sin tarea activa bloquea el código con exit 2 y el motivo" '$T check src/app.ts >/dev/null 2>&1; [ $? -eq 2 ] && $T check src/app.ts 2>&1 | grep -q "Cero Código sin Tarea"'
check "check deja editar Markdown y docs/ sin tarea activa" '$T check README.md docs/guia.md >/dev/null 2>&1'
check "check con varias rutas sale con 2 si alguna está bloqueada" '$T check README.md src/app.ts >/dev/null 2>&1; [ $? -eq 2 ]'
check "check sin rutas es un error de uso (exit 1)" '$T check >/dev/null 2>&1; [ $? -eq 1 ]'
mkdir -p docs
check "desde un subdirectorio, ../src bloquea igual que el hook con la ruta absoluta" '(cd docs && ../.agents/scripts/task.sh check ../src/app.ts >/dev/null 2>&1; [ $? -eq 2 ])'
check "desde un subdirectorio, una ruta relativa exenta sigue permitida" '(cd docs && ../.agents/scripts/task.sh check guia.md >/dev/null 2>&1)'
check "check normaliza .. (no se cuela por una ruta exenta)" '$T check .agents/../src/app.ts >/dev/null 2>&1; [ $? -eq 2 ]'
check "con el directorio actual borrado, check bloquea (exit 2) en vez de dejar pasar" 'P="$PWD"; d=$(mktemp -d); (cd "$d" && rmdir "$d" && bash "$P/.agents/scripts/pre-edit-check.sh" src/app.ts >/dev/null 2>&1; [ $? -eq 2 ])'
$T add "Tarea para comprobar ediciones" "backend-agent" "criterio" >/dev/null
$T start "$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)" >/dev/null 2>&1
$T learn "Consulta sin indice en el listado de pedidos de clientes" database "c" "Crear indice en la FK" --paths "src/db/*.ts" >/dev/null
check "con tarea activa permite editar código" '$T check src/app.ts >/dev/null 2>&1'
check "muestra las lecciones cuyo ámbito cubre la ruta, con su antídoto" '$T check src/db/orders.ts 2>&1 | grep -q "Consulta sin indice" && $T check src/db/orders.ts 2>&1 | grep -q "Crear indice en la FK"'
check "muestra las lecciones siempre (sin deduplicar por sesión)" '$T check src/db/orders.ts 2>&1 | grep -q "Consulta sin indice" && $T check src/db/orders.ts 2>&1 | grep -q "Consulta sin indice"'
check "no muestra lecciones de otras rutas" '$T check src/app.ts 2>&1 | grep -q "Sin lecciones específicas"'
check "usa el proyecto del script aunque CLAUDE_PROJECT_DIR apunte a otro" 'CLAUDE_PROJECT_DIR="$WORK" $T check src/db/orders.ts 2>&1 | grep -q "Consulta sin indice"'
check "desde un subdirectorio, las rutas relativas se toman del directorio actual (lecciones)" '(cd src && "$PWD/../.agents/scripts/task.sh" check db/orders.ts 2>&1 | grep -q "Consulta sin indice")'
check "check no modifica ningún archivo" 'cp GLOBAL_STATE.md "$WORK/gs" && cp BRAIN.md "$WORK/br" && $T check src/db/a.ts README.md >/dev/null 2>&1; cmp -s GLOBAL_STATE.md "$WORK/gs" && cmp -s BRAIN.md "$WORK/br"'
git checkout -q main 2>/dev/null
cd "$WORK" || exit 1

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

# ------------------------------------------------------------------------------
section "install-hooks.sh en worktrees y con core.hooksPath"
new_project hookswt
rm -f .git/hooks/commit-msg .git/hooks/pre-commit
git worktree add -q "$WORK/hookswt-arbol" -b arbol-hooks 2>/dev/null
check "install-hooks.sh funciona desde un worktree (.git es un archivo)" '(cd "$WORK/hookswt-arbol" && bash ./.agents/scripts/install-hooks.sh >/dev/null 2>&1) && [ -x .git/hooks/commit-msg ] && [ -x .git/hooks/pre-commit ]'
check "con los hooks del worktree, un commit sin TASK-XXX se rechaza" '(cd "$WORK/hookswt-arbol" && echo x > nota.txt && git add nota.txt && ! git commit -qm "sin formato" >/dev/null 2>&1)'
check "install-hooks.sh desde un subdirectorio se niega (exit 1) en vez de instalar en el repositorio que lo contiene" 'mkdir -p sub && ! (cd sub && bash ../.agents/scripts/install-hooks.sh >/dev/null 2>&1)'
# init-project en worktrees de un repositorio sin hooks (instalación nueva, --adopt y --update)
WTBASE="$WORK/wt-base"; mkdir -p "$WTBASE"
git -C "$WTBASE" init -q -b main && git -C "$WTBASE" -c user.email=t@e -c user.name=t commit -q --allow-empty -m init
git -C "$WTBASE" worktree add -q "$WORK/wt-nuevo" -b wt-nuevo 2>/dev/null
bash "$ROOT/.agents/scripts/init-project.sh" "Proyecto WT" "$WORK/wt-nuevo" >/dev/null 2>&1
check "init-project.sh en un worktree instala los git hooks" '[ -x "$WTBASE/.git/hooks/commit-msg" ] && [ -x "$WTBASE/.git/hooks/pre-commit" ]'
rm -f "$WTBASE/.git/hooks/commit-msg" "$WTBASE/.git/hooks/pre-commit"
bash "$ROOT/.agents/scripts/init-project.sh" --update "$WORK/wt-nuevo" >/dev/null 2>&1
check "init-project.sh --update en un worktree reinstala los git hooks" '[ -x "$WTBASE/.git/hooks/commit-msg" ]'
rm -f "$WTBASE/.git/hooks/commit-msg" "$WTBASE/.git/hooks/pre-commit"
git -C "$WTBASE" worktree add -q "$WORK/wt-adopt" -b wt-adopt 2>/dev/null
bash "$ROOT/.agents/scripts/init-project.sh" --adopt "$WORK/wt-adopt" >/dev/null 2>&1
check "init-project.sh --adopt en un worktree instala los git hooks" '[ -x "$WTBASE/.git/hooks/commit-msg" ] && [ -x "$WTBASE/.git/hooks/pre-commit" ]'
SUBDIR_REPO="$WORK/sub-de-repo/app"; mkdir -p "$SUBDIR_REPO"; git -C "$WORK/sub-de-repo" init -q -b main
bash "$ROOT/.agents/scripts/init-project.sh" "Sub" "$SUBDIR_REPO" >/dev/null 2>&1
check "init-project.sh en un subdirectorio de otro repositorio no instala hooks en ese repositorio" '! [ -e "$WORK/sub-de-repo/.git/hooks/commit-msg" ]'
cd "$WORK" || exit 1
new_project hookspath
mkdir -p .husky && printf '#!/bin/sh\necho husky\n' > .husky/commit-msg && chmod +x .husky/commit-msg
git config core.hooksPath .husky
bash ./.agents/scripts/install-hooks.sh >/dev/null 2>&1
check "con core.hooksPath instala en ese directorio sin pisar hooks existentes" 'grep -q "echo husky" .husky/commit-msg && [ -x .husky/pre-commit ] && grep -q "scan-secrets" .husky/pre-commit'
git config --unset core.hooksPath

# ------------------------------------------------------------------------------
section "task.sh: comandos desconocidos, colores y señales"
new_project cli
check "un comando desconocido sale con exit 1 y lo dice por stderr" 'OUT=$($T clsoe TASK-001 2>&1 >/dev/null); [ $? -eq 1 ] && printf "%s" "$OUT" | grep -q "comando desconocido" && [ -z "$($T clsoe 2>/dev/null)" ]'
check "help, -h, --help y sin argumentos salen con exit 0" '$T help >/dev/null && $T -h >/dev/null && $T --help >/dev/null && $T >/dev/null'
tty_out() { python3 -c 'import os,pty,sys
out=b""
pid,fd=pty.fork()
if pid==0:
    os.execvp(sys.argv[1], sys.argv[1:])
while True:
    try: d=os.read(fd,4096)
    except OSError: break
    if not d: break
    out+=d
os.waitpid(pid,0)
sys.stdout.write("ESC" if b"\x1b[" in out else "PLAIN")' "$@"; }
check "en una terminal task.sh usa colores" '[ "$(TERM=xterm tty_out bash $T list)" = ESC ]'
check "NO_COLOR=1 desactiva los colores aunque sea una terminal" '[ "$(TERM=xterm NO_COLOR=1 tty_out bash $T list)" = PLAIN ] && [ "$(TERM=dumb tty_out bash $T list)" = PLAIN ]'
FAKEBIN="$WORK/fakegit-bin"; mkdir -p "$FAKEBIN"
REALGIT="$(command -v git)"
printf '#!/usr/bin/env bash\ncase " $* " in *" checkout "*) : > "%s/en-checkout"; sleep 2 ;; esac\nexec "%s" "$@"\n' "$WORK" "$REALGIT" > "$FAKEBIN/git"
chmod +x "$FAKEBIN/git"
# Lanza 'task.sh start' con un git que se detiene en checkout (lock tomado y GLOBAL_STATE.md a
# medio escribir), le envía la señal y devuelve su código de salida
signal_start() {
  local sig="$1" id
  $T add "Tarea para probar $sig" backend-agent "c" >/dev/null
  id="$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | sort -u | tail -1)"
  rm -f "$WORK/en-checkout"
  SIG="$sig" MARK="$WORK/en-checkout" PATH="$FAKEBIN:$PATH" python3 -c '
import os, signal, subprocess, sys, time
p = subprocess.Popen(["bash", sys.argv[1], "start", sys.argv[2]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
for _ in range(200):
    if os.path.exists(os.environ["MARK"]): break
    time.sleep(0.05)
p.send_signal(getattr(signal, os.environ["SIG"]))
print(p.wait())' "$T" "$id"
}
check "SIGTERM a mitad de una escritura termina task.sh (exit 143) en vez de continuar" '[ "$(signal_start SIGTERM)" = 143 ] && [ ! -d .agents/.task_lock ]'
git checkout -q main 2>/dev/null
check "SIGINT (Ctrl-C) a mitad de una escritura termina task.sh (exit 130)" '[ "$(signal_start SIGINT)" = 130 ] && [ ! -d .agents/.task_lock ]'
git checkout -q main 2>/dev/null
check "tras las señales el lock queda liberado y task.sh sigue operativo" '$T add "Tras la señal" backend-agent "c" >/dev/null'
check "con stdout en terminal, los errores redirigidos a un log no llevan códigos ANSI" 'TERM=xterm tty_out bash -c "$T clsoe 2>\"$WORK/err.log\"" >/dev/null; [ -s "$WORK/err.log" ] && ! grep -q $(printf "\033") "$WORK/err.log"'
check "test-skills.sh usa colores en terminal y los desactiva con NO_COLOR" '[ "$(TERM=xterm tty_out bash "$ROOT/tests/test-skills.sh")" = ESC ] && [ "$(TERM=xterm NO_COLOR=1 tty_out bash "$ROOT/tests/test-skills.sh")" = PLAIN ]'

# ------------------------------------------------------------------------------
section "task.sh: doctor y diff"
new_project doc_diff
check "task.sh doctor sale con 0 en un proyecto limpio" '$T doctor >/dev/null'
check "task.sh doctor --kickoff ejecuta diagnóstico pre-vuelo exitosamente" '$T doctor --kickoff | grep -q "Diagnóstico Pre-Vuelo" && $T doctor -k >/dev/null'
check "bin/skill-maestro.js kickoff ejecuta diagnóstico pre-vuelo exitosamente" 'node "$ROOT/bin/skill-maestro.js" kickoff | grep -q "Diagnóstico Pre-Vuelo"'
check "init-project.sh --interactive acepta inputs y genera proyecto válido" 'printf "TestApp\n./test-app\n1\n1\ns\ns\n" | bash "$ROOT/.agents/scripts/init-project.sh" --interactive >/dev/null && [ -f test-app/GLOBAL_STATE.md ] && grep -q "nextjs" test-app/GLOBAL_STATE.md && rm -rf test-app'
check "task.sh doctor falla (exit 1) si GLOBAL_STATE.md tiene errores" 'printf "\n| \`TASK-001\` | dup | backend-agent | \`TODO\` | \`0/3\` | c |\n" >> GLOBAL_STATE.md; ! $T doctor >/dev/null'
git checkout -q GLOBAL_STATE.md
check "task.sh doctor falla (exit 1) si hay un secreto expuesto" 'printf "%s\n" "$FAKE_KEY" > secret.txt; git add secret.txt; ! $T doctor >/dev/null; git reset -q HEAD secret.txt 2>/dev/null; rm -f secret.txt'

$T add "Probar diff" backend-agent "criterios" >/dev/null
git commit -qm "chore(TASK-001): registrar tarea" GLOBAL_STATE.md --no-verify
TASK_DIFF_ID="$(grep -oE "TASK-[0-9]+" GLOBAL_STATE.md | tail -1)"
check "task.sh diff sin rama de tarea ni IN_PROGRESS falla con exit 1" '! $T diff >/dev/null 2>&1'
$T start "$TASK_DIFF_ID" >/dev/null
DIFF_BRANCH="$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -E "^(feature|fix|refactor)/${TASK_DIFF_ID}" | head -1)"
git checkout -q main 2>/dev/null
check "task.sh diff sin cambios informa y sale con 0" 'OUT=$($T diff "$TASK_DIFF_ID"); [ $? -eq 0 ] && printf "%s" "$OUT" | grep -q "No hay cambios"'
git checkout -q "$DIFF_BRANCH" 2>/dev/null
printf "console.log(\x27cambio\x27);\n" > app.js
git add app.js
check "task.sh diff en la rama activa muestra el diff" 'OUT=$($T diff); [ $? -eq 0 ] && printf "%s" "$OUT" | grep -q "cambio"'
check "task.sh diff --stat muestra el resumen de archivos" 'OUT=$($T diff --stat); [ $? -eq 0 ] && printf "%s" "$OUT" | grep -q "app.js" && ! printf "%s" "$OUT" | grep -q "console.log"'
$T commit "$TASK_DIFF_ID" "anadir app.js" feat >/dev/null
git checkout -q main 2>/dev/null
check "task.sh diff TASK-ID desde main muestra los cambios de esa rama" 'OUT=$($T diff "$TASK_DIFF_ID"); [ $? -eq 0 ] && printf "%s" "$OUT" | grep -q "cambio"'
check "task.sh diff TASK-999 inexistente falla con exit 1" '! $T diff TASK-999 >/dev/null 2>&1'
cd "$WORK" || exit 1

# ------------------------------------------------------------------------------
section "evolución del cerebro: alertas de reincidencia, hotspots, prefer, stack filter y brain lint"
new_project brain_evol

# 1. Alertas visuales de reincidencia
$T add "Probar parser" backend-agent "criterios" >/dev/null
$T start TASK-001 >/dev/null
$T learn "Fallo recurrente en parseo" TESTING "Parser antiguo" "Usar parser nuevo" --paths "src/parser/*.ts" >/dev/null
LL_REC_ID="$(grep -oE "LL-[0-9]+" .agents/brain/lessons_learned.md | tail -1)"
printf "| \`2026-11-19\` | \`TASK-001\` | %s | Fallo recurrente en parseo |\n" "$LL_REC_ID" >> .agents/brain/recurrences.md
check "task.sh brain for muestra ALERTA CRITICA y reincidencias históricas" 'OUT=$($T brain for TASK-001 src/parser/index.ts); printf "%s" "$OUT" | grep -q "ALERTA CRÍTICA" && printf "%s" "$OUT" | grep -q "reincidencias históricas"'
check "task.sh check muestra ALERTA CRITICA y REINCIDENTE x1 ante ruta reincidente" 'OUT=$($T check src/parser/index.ts); printf "%s" "$OUT" | grep -q "ALERTA CRÍTICA" && printf "%s" "$OUT" | grep -q "REINCIDENTE x1"'

# 2. task.sh brain hotspots
check "task.sh brain hotspots calcula el ranking de riesgo y sale con 0" 'OUT=$($T brain hotspots); [ $? -eq 0 ] && printf "%s" "$OUT" | grep -q "Hotspots de Riesgo" && printf "%s" "$OUT" | grep -q "src/parser/\*\.ts"'

# 3. task.sh prefer
check "task.sh prefer registra una regla en preferences.md" '$T prefer "Estilo de Código" "Usar const en vez de let si no se reasigna" >/dev/null && grep -q "Usar const en vez de let" .agents/brain/preferences.md'
check "task.sh prefer es idempotente y no duplica la regla existente" 'OUT=$($T prefer "Estilo de Código" "Usar const en vez de let si no se reasigna"); printf "%s" "$OUT" | grep -q "ya está registrada" && [ $(grep -c "Usar const en vez de let" .agents/brain/preferences.md) -eq 1 ]'
check "task.sh prefer crea una categoria nueva si no existe" '$T prefer "Seguridad Web" "Configurar cabeceras CSP estrictas" >/dev/null && grep -qE "## .*Seguridad Web" .agents/brain/preferences.md'

# 4. Filtrado de lecciones por stack
$T learn "Quirk específico de FastAPI" "BACKEND:fastapi" "Pydantic v2" "Usar model_dump" --paths "app/*.py" >/dev/null
LL_FASTAPI_ID="$(grep -oE "LL-[0-9]+" .agents/brain/lessons_learned.md | tail -1)"
check "lección con etiqueta :fastapi no aparece si MAESTRO_STACK es angular-express" 'OUT=$(MAESTRO_STACK=angular-express $T brain for TASK-001 app/main.py); ! printf "%s" "$OUT" | grep -q "$LL_FASTAPI_ID"'
check "lección con etiqueta :fastapi aparece si MAESTRO_STACK es fastapi" 'OUT=$(MAESTRO_STACK=fastapi $T brain for TASK-001 app/main.py); printf "%s" "$OUT" | grep -q "$LL_FASTAPI_ID"'

# 5. task.sh brain lint
printf '#!/usr/bin/env bash\nawk -v x=1 "{ print \\\s }" test.txt\n' > bad_awk.sh
check "task.sh brain lint detecta antipatrón LL-001 (\\s en awk) y sale con 1" '! $T brain lint bad_awk.sh >/dev/null 2>&1'
check "task.sh brain lint muestra el antídoto de LL-001" 'OUT=$($T brain lint bad_awk.sh 2>&1 || true); printf "%s" "$OUT" | grep -q "LL-001" && printf "%s" "$OUT" | grep -q "Antídoto"'
printf '#!/usr/bin/env bash\nsed "y/á/a/" test.txt\n' > bad_sed.sh
check "task.sh brain lint detecta antipatrón LL-007 (sed y///) y sale con 1" '! $T brain lint bad_sed.sh >/dev/null 2>&1'
printf '#!/usr/bin/env bash\nawk "{ print \$1 }" test.txt\n' > clean.sh
check "task.sh brain lint sale con 0 en script sin antipatrones" '$T brain lint clean.sh >/dev/null'
rm -f bad_awk.sh bad_sed.sh clean.sh

# 6. task.sh doctor con linter integrado
check "task.sh doctor incluye el paso de brain lint y completa los 5 pasos" 'OUT=$($T doctor); [ $? -eq 0 ] && printf "%s" "$OUT" | grep -q "\[3/5\] Linter de Antipatrones" && printf "%s" "$OUT" | grep -q "\[5/5\]"'
printf '#!/usr/bin/env bash\nawk -v x=1 "{ print \\\s }" test.txt\n' > bad_in_repo.sh
check "task.sh doctor falla (exit 1) si hay antipatrón detectado por brain lint" '! $T doctor >/dev/null 2>&1'
rm -f bad_in_repo.sh

# 7. task.sh dashboard
check "task.sh dashboard genera el archivo HTML por defecto" 'rm -f docs/dashboard.html; $T dashboard >/dev/null && [ -f docs/dashboard.html ] && grep -q "<!DOCTYPE html>" docs/dashboard.html'
check "task.sh dashboard --output personalizado funciona" 'rm -f custom.html; $T dashboard --output custom.html >/dev/null && [ -f custom.html ] && grep -q "Dashboard" custom.html && rm -f custom.html'
check "task.sh serve inicia el servidor Live Dashboard y responde en /api/status" 'python3 "$ROOT/.agents/scripts/dashboard-server.py" --port 4319 >/dev/null 2>&1 & SPID=$!; sleep 1; curl -s http://127.0.0.1:4319/api/status | grep -q "metrics"; RC=$?; kill $SPID 2>/dev/null; [ $RC -eq 0 ]'
check "dashboard-server.py 2.0 soporta SSE /api/events, creacion de tareas /api/action y streaming de doctor" 'python3 "$ROOT/.agents/scripts/dashboard-server.py" --port 4321 >/dev/null 2>&1 & SPID=$!; sleep 1; SSE_OUT=$(curl -s -m 2 http://127.0.0.1:4321/api/events || true); echo "$SSE_OUT" | grep -q "event: state"; R1=$?; POST_OUT=$(curl -s -X POST http://127.0.0.1:4321/api/action -H "Content-Type: application/json" -d "{\"action\": \"add\", \"description\": \"Tarea web test\", \"agent\": \"frontend-agent\", \"criteria\": \"criterios web\"}"); echo "$POST_OUT" | grep -q "\"ok\": true"; R2=$?; DOC_STREAM=$(curl -s -m 4 "http://127.0.0.1:4321/api/doctor/stream?kickoff=1" || true); echo "$DOC_STREAM" | grep -q "event: log"; R3=$?; kill $SPID 2>/dev/null; [ $R1 -eq 0 ] && [ $R2 -eq 0 ] && [ $R3 -eq 0 ]'

# 8. AWAITING_HUMAN_APPROVAL, task.sh hold y approve
$T add "Tarea para punto de control humano" "backend-agent" "criterios" >/dev/null
TASK_CTRL=$(grep "Tarea para punto de control humano" GLOBAL_STATE.md | grep -oE "TASK-[0-9]+" | head -1)
check "task.sh hold pone la tarea en AWAITING_HUMAN_APPROVAL" '$T hold "$TASK_CTRL" "esperando visto bueno" >/dev/null && grep "$TASK_CTRL" GLOBAL_STATE.md | grep -q "AWAITING_HUMAN_APPROVAL"'
check "validate-state acepta AWAITING_HUMAN_APPROVAL sin errores" 'bash "$ROOT/.agents/scripts/validate-state.sh" >/dev/null'
check "task.sh start sobre AWAITING_HUMAN_APPROVAL falla" '! $T start "$TASK_CTRL" >/dev/null 2>&1'
check "task.sh approve reanuda a TODO y registra en historial" '$T approve "$TASK_CTRL" --status TODO --comment "Aprobado plan" >/dev/null && grep "$TASK_CTRL" GLOBAL_STATE.md | grep -q "| \`TODO\` |" && grep -q "Aprobado plan" GLOBAL_STATE.md'
$T hold "$TASK_CTRL" "segundo hold" >/dev/null
check "task.sh approve --status IN_PROGRESS reanuda a IN_PROGRESS" '$T approve "$TASK_CTRL" --status IN_PROGRESS >/dev/null && grep "$TASK_CTRL" GLOBAL_STATE.md | grep -q "| \`IN_PROGRESS\` |"'
check "task.sh approve sobre tarea que no está en AWAITING_HUMAN_APPROVAL falla" '! $T approve "$TASK_CTRL" >/dev/null 2>&1'

# 9. task.sh contracts validate
check "task.sh contracts validate valida contracts_template.json con éxito (exit 0)" '$T contracts validate "$ROOT/.agents/templates/contracts_template.json" >/dev/null'
check "task.sh contracts validate falla si el archivo no existe (exit 1)" '! $T contracts validate "nonexistent.json" >/dev/null 2>&1'
printf '{"version": "1.0", "endpoints": [{"method": "INVALID", "path": "/foo"}]}' > bad_contract.json
check "task.sh contracts validate detecta método HTTP inválido (exit 1)" '! $T contracts validate bad_contract.json >/dev/null 2>&1'
printf '{"version": "1.0", "endpoints": [{"method": "GET", "path": "no_slash"}]}' > bad_path.json
check "task.sh contracts validate detecta path sin barra inicial (exit 1)" '! $T contracts validate bad_path.json >/dev/null 2>&1'
printf '{"endpoints": []}' > no_version.json
check "task.sh contracts validate detecta falta de versión (exit 1)" '! $T contracts validate no_version.json >/dev/null 2>&1'
printf '{"version": "1.0", "endpoints": [{"method": "GET", "path": "/test"}]}' > valid_contract.json
check "task.sh contracts validate valida contrato mínimo válido (exit 0)" '$T contracts validate valid_contract.json >/dev/null'
rm -f bad_contract.json bad_path.json no_version.json valid_contract.json
check "task.sh contracts con subcomando inválido falla (exit 1)" '! $T contracts invalid_sub >/dev/null 2>&1'
check "task.sh contracts mock inicia el servidor mock y responde en /__health y endpoints simulados" '$T contracts mock --port 4390 --file "$ROOT/.agents/templates/contracts_template.json" >/dev/null 2>&1 & MPID=$!; sleep 1; HEALTH=$(curl -s http://127.0.0.1:4390/__health || true); echo "$HEALTH" | grep -q "skill-maestro-mock-server"; R1=$?; LOGIN_MOCK=$(curl -s -X POST http://127.0.0.1:4390/auth/login || true); echo "$LOGIN_MOCK" | grep -q "token"; R2=$?; kill $MPID 2>/dev/null; [ $R1 -eq 0 ] && [ $R2 -eq 0 ]'

# 10. task.sh swarm
check "task.sh swarm status muestra el estado del enjambre" '$T swarm status | grep -q "Enjambre Multi-Agente"'
check "task.sh swarm list lista las tareas en formato estructurado" '$T swarm list | grep -q "ID	AGENTE	ESTADO"'
check "task.sh swarm con subcomando desconocido falla con exit 1" '! $T swarm invalid_cmd >/dev/null 2>&1'
check "task.sh swarm spawn sin ID falla con exit 1" '! $T swarm spawn >/dev/null 2>&1'
check "task.sh swarm spawn crea un workspace aislado bajo .agents/workspaces/" '$T add "Tarea swarm aislado" "backend-agent" "criterios" >/dev/null && TSWARM=$(grep "Tarea swarm aislado" GLOBAL_STATE.md | grep -oE "TASK-[0-9]+" | head -1) && $T swarm spawn "$TSWARM" >/dev/null && [ -d ".agents/workspaces/$TSWARM" ]'
check "task.sh swarm clean limpia el workspace aislado de la tarea" '$T swarm clean "$TSWARM" >/dev/null && [ ! -d ".agents/workspaces/$TSWARM" ]'
check "task.sh swarm merge sin ID falla con exit 1" '! $T swarm merge >/dev/null 2>&1'
check "task.sh swarm merge sobre tarea no DONE falla con exit 1" '! $T swarm merge "$TSWARM" >/dev/null 2>&1'
check "task.sh swarm merge sobre tarea DONE fusiona a main exitosamente" 'mkdir -p .agents/reviews && printf "# Reporte\n- **Tarea**: %s\n- **Revisor**: qa-security-agent\n- **Veredicto**: APROBADO\n" "$TSWARM" > ".agents/reviews/qa_${TSWARM}.md" && $T handoff "$TSWARM" >/dev/null && $T close "$TSWARM" --no-lesson "test" >/dev/null && $T swarm merge "$TSWARM" >/dev/null && ! git branch --format="%(refname:short)" | grep -q "$TSWARM"'

cd "$WORK" || exit 1

printf "\nResultado: %d OK, %d fallidas\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
