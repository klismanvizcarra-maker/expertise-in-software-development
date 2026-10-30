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

check "--stack con valor desconocido sale con exit 1" '! bash "$ROOT/.agents/scripts/init-project.sh" "App" . --stack desconocido >/dev/null 2>&1'

mkdir -p "$WORK/escaped-app" && git -C "$WORK/escaped-app" init -q
bash "$ROOT/.agents/scripts/init-project.sh" "I&D / Innovation & SaaS" "$WORK/escaped-app" >/dev/null 2>&1
check "nombres de proyecto con & o / se sustituyen literalmente" 'grep -q "I&D / Innovation & SaaS" "$WORK/escaped-app/GLOBAL_STATE.md" && grep -q "I&D / Innovation & SaaS" "$WORK/escaped-app/README.md"'

mkdir -p "$WORK/ci-app" && git -C "$WORK/ci-app" init -q
bash "$ROOT/.agents/scripts/init-project.sh" "Mi App CI" "$WORK/ci-app" --ci >/dev/null 2>&1
check "init-project --ci instala .github/workflows/audit.yml" '[ -f "$WORK/ci-app/.github/workflows/audit.yml" ] && grep -q "Audit" "$WORK/ci-app/.github/workflows/audit.yml"'
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
CLOSE_OUT=$($T close TASK-003)
check "close tras revisión con revisor independiente -> DONE" '[ "$(col TASK-003 5)" = DONE ]'
check "close muestra comando de fusión a main" 'echo "$CLOSE_OUT" | grep -q "git merge --no-ff"'

$T add "Tarea con verificación" "backend-agent" "criterios" >/dev/null
$T start TASK-007 >/dev/null
$T handoff TASK-007 qa-security-agent --verify "npm test" --verify "npm run build" --summary "Entrega con pruebas" >/dev/null
J7=.agents/handoffs/handoff_TASK-007.json
check "handoff con --verify guarda comandos en JSON" 'python3 -c "import json,sys; d=json.load(open(\"$J7\")); sys.exit(0 if d[\"verification_commands\"]==[\"npm test\", \"npm run build\"] else 1)"'
check "handoff con --verify y --summary registra fila en historial de GLOBAL_STATE.md" 'grep -q "Entrega con pruebas. Comandos: \`npm test\`, \`npm run build\`" GLOBAL_STATE.md'

# ------------------------------------------------------------------------------
section "task.sh learn / debt"
new_project brain
$T learn "Problema A" backend "Causa A" "Solucion A" >/dev/null
$T learn "Problema B" database >/dev/null
check "learn numera LL-001 y LL-002 sin duplicados" '[ "$(grep -c "LL-001" BRAIN.md)" = 1 ] && grep -q "LL-002" BRAIN.md && grep -q "LL-002" .agents/brain/lessons_learned.md'
check "learn: 7 columnas en BRAIN.md y 6 en lessons_learned.md" '[ "$(grep "Problema A" BRAIN.md | awk -F"|" "{print NF-2}")" = 7 ] && [ "$(grep "Problema A" .agents/brain/lessons_learned.md | awk -F"|" "{print NF-2}")" = 6 ]'
$T debt "Paginacion en memoria" TASK-001 "Paginar en SQL" baja >/dev/null
check "debt registra TD-001 con prioridad normalizada" 'grep -q "TD-001.*\`BAJA\`" .agents/brain/tech_debt.md'
check "debt con prioridad inválida falla" '! $T debt "x" TASK-001 "y" URGENTE >/dev/null 2>&1'
TEMPLATE_SUM=$(cksum < .agents/templates/BRAIN_TEMPLATE.md)
mv BRAIN.md "$WORK/brain.bak"
check "learn sin BRAIN.md falla sin tocar plantillas" '! $T learn "x" >/dev/null 2>&1 && [ "$(cksum < .agents/templates/BRAIN_TEMPLATE.md)" = "$TEMPLATE_SUM" ]'
mv "$WORK/brain.bak" BRAIN.md

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
section "test-skills.sh (linter estructural de skills)"
check "auditoría estructural de skills sin errores" 'bash "$ROOT/tests/test-skills.sh" >/dev/null'
check "test-skills.sh sale con exit 1 ante errores" 'bash -c "FAKE=\$(mktemp -d); cp -r \"$ROOT/tests\" \"\$FAKE/\"; mkdir -p \"\$FAKE/.agents/skills/broken-agent\"; cat > \"\$FAKE/.agents/skills/broken-agent/SKILL.md\" <<\"EOF\"
---
name: broken-agent
description: corta
---
# broken
EOF
bash \"\$FAKE/tests/test-skills.sh\" >/dev/null 2>&1; ret=\$?; rm -rf \"\$FAKE\"; exit \$ret"; [ $? -eq 1 ]'

printf "\nResultado: %d OK, %d fallidas\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
