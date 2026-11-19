#!/usr/bin/env bash
# ==============================================================================
# Biblioteca del Cerebro (memoria a largo plazo): la carga task.sh
# ==============================================================================
# Fuente única de lecciones: .agents/brain/lessons_learned.md, con 8 columnas:
#   | ID | Fecha | Categoría | Problema | Causa Raíz | Solución | Ámbito | Estado |
# La tabla de lecciones de BRAIN.md es una copia generada con brain_sync: no se edita a mano.
#
# Ámbito: globs de rutas separados por comas (ej. `.agents/scripts/*.sh,tests/*.sh`) a las
# que aplica la lección; `*` = general (no ligada a archivos concretos). Semántica del glob:
#   - `*` casa cualquier secuencia, también `/` (`src/api/*.ts` cubre `src/api/v1/x.ts`);
#     `?` casa un carácter; el resto es literal.
#   - El glob ancla al final de la ruta y al inicio o a un límite de directorio, así que vale
#     para rutas relativas y absolutas (`src/api/*.ts` cubre `/repo/src/api/x.ts`).
#   - Un glob terminado en `/` cubre todo lo que haya dentro de ese directorio.
#
# Requiere definidos: BRAIN_FILE, LL_FILE, DEBT_FILE, STATE_FILE y las funciones die y
# replace_file. Compatible con bash 3.2 y awk/sed BSD y GNU; python3 es opcional.
# ==============================================================================

BRAIN_HDR_LESSONS='^\|[ \t]*ID[ \t]*\|[ \t]*Fecha[ \t]*\|[ \t]*Categor'
BRAIN_LL_HEADER='| ID | Fecha | Categoría | Problema Encontrado | Causa Raíz | Solución Aplicada (Antídoto) | Ámbito | Estado |'
BRAIN_LL_SEP='| :---: | :---: | :---: | :--- | :--- | :--- | :--- | :---: |'
BRAIN_HDR_DEBT='^\|[ \t]*ID[ \t]*\|[ \t]*Tarea Vinculada'
BRAIN_DEBT_HEADER='| ID | Tarea Vinculada | Descripción de la Deuda | Solución Temporal Aplicada | Acción Definitiva Pendiente | Prioridad |'
BRAIN_DEBT_SEP='| :---: | :---: | :--- | :--- | :--- | :---: |'

# Minúsculas y sin tildes, línea a línea (tolower de awk BSD no baja Á/Ó en locale C)
norm_text() {
  if command -v python3 >/dev/null 2>&1; then
    PYTHONIOENCODING=utf-8 python3 -c 'import sys, unicodedata
for line in sys.stdin:
    sys.stdout.write("".join(c for c in unicodedata.normalize("NFKD", line) if not unicodedata.combining(c)).lower())'
  else
    # Sin python3: sustituciones byte a byte, válidas en cualquier locale (y/// falla en locale C)
    sed -e 's/á/a/g;s/à/a/g;s/ä/a/g;s/â/a/g;s/ã/a/g;s/Á/a/g;s/À/a/g;s/Ä/a/g;s/Â/a/g;s/Ã/a/g' \
        -e 's/é/e/g;s/è/e/g;s/ë/e/g;s/ê/e/g;s/É/e/g;s/È/e/g;s/Ë/e/g;s/Ê/e/g' \
        -e 's/í/i/g;s/ì/i/g;s/ï/i/g;s/î/i/g;s/Í/i/g;s/Ì/i/g;s/Ï/i/g;s/Î/i/g' \
        -e 's/ó/o/g;s/ò/o/g;s/ö/o/g;s/ô/o/g;s/õ/o/g;s/Ó/o/g;s/Ò/o/g;s/Ö/o/g;s/Ô/o/g;s/Õ/o/g' \
        -e 's/ú/u/g;s/ù/u/g;s/ü/u/g;s/û/u/g;s/Ú/u/g;s/Ù/u/g;s/Ü/u/g;s/Û/u/g' \
        -e 's/ñ/n/g;s/Ñ/n/g;s/ç/c/g;s/Ç/c/g' \
      | tr '[:upper:]' '[:lower:]'
  fi
}

# Categoría de lecciones que corresponde al agente asignado a una tarea
agent_category() {
  case "$1" in
    backend-agent)            echo BACKEND ;;
    frontend-agent)           echo FRONTEND ;;
    database-architect-agent) echo DATABASE ;;
    qa-security-agent)        echo SECURITY ;;
    devops-cloud-agent)       echo DEVOPS ;;
    mobile-agent)             echo MOBILE ;;
    ai-integrator-agent)      echo AI ;;
    ui-ux-agent)              echo UI/UX ;;
    domain-logic-agent)       echo DOMAIN ;;
    docs-architecture-agent)  echo DOCS ;;
    *)                        echo "" ;;
  esac
}

# Normaliza un ámbito: recorta espacios alrededor de cada glob (los interiores se conservan),
# quita backticks y elementos vacíos. Imprime vacío si no queda ningún glob.
norm_scope() {
  printf '%s' "$1" | tr -d '`' | tr '\t' ' ' | awk '
    { n = split($0, parts, ","); out = ""
      for (i = 1; i <= n; i++) { g = parts[i]; gsub(/^ +| +$/, "", g); if (g != "") out = out (out == "" ? "" : ",") g }
      printf "%s", out }'
}

# Crea lessons_learned.md si falta (proyectos antiguos podían no tenerlo): desde la plantilla,
# sin sus filas de ejemplo, o con una tabla mínima
ensure_lessons_file() {
  [ -f "$LL_FILE" ] && return 0
  local tpl
  tpl="$(dirname "$LL_FILE")/../templates/lessons_learned_template.md"
  mkdir -p "$(dirname "$LL_FILE")"
  if [ -f "$tpl" ]; then
    grep -vE '^\|[ \t]*`?LL-[0-9]+' "$tpl" > "$LL_FILE" || true
  fi
  if ! grep -qE "$BRAIN_HDR_LESSONS" "$LL_FILE" 2>/dev/null; then
    printf '%s\n\n%s\n%s\n' '# Lecciones Aprendidas y Antipatrones (Lessons Learned)' "$BRAIN_LL_HEADER" "$BRAIN_LL_SEP" > "$LL_FILE"
  fi
}

# Incorpora a la fuente única las lecciones que solo existan en BRAIN.md (con 7 u 8 columnas),
# para que regenerar la tabla de BRAIN.md nunca pierda una lección
adopt_brain_lessons() {
  [ -f "$BRAIN_FILE" ] && [ -f "$LL_FILE" ] || return 0
  local missing tmp
  missing=$(LLF="$LL_FILE" awk -F'|' '
    function cid(   c) { c = $2; gsub(/[ \t`\r]/, "", c); return c }
    !/^\|/ || cid() !~ /^LL-[0-9]+$/ { next }
    FILENAME == ENVIRON["LLF"] { have[cid()] = 1; next }
    !(cid() in have) {
      have[cid()] = 1
      st = $(NF-1); gsub(/[ \t`]/, "", st)
      if (st != "ACTIVO" && st != "OBSOLETA") st = "ACTIVO"
      line = $0
      sub(/\r$/, "", line)
      if (NF - 2 >= 8) { sub(/[ \t]*\|[ \t]*$/, " |", line); print line }
      else if (NF - 2 == 7) { sub(/\|[^|]*\|[ \t]*$/, "", line); sub(/[ \t]+$/, "", line); print line " | `*` | `" st "` |" }
      else { sub(/[ \t]*\|[ \t]*$/, "", line); print line " | `*` | `ACTIVO` |" }   # sin columna Estado
    }
  ' "$LL_FILE" "$BRAIN_FILE")
  [ -n "$missing" ] || return 0
  tmp=$(mktemp)
  HDR="$BRAIN_HDR_LESSONS" ROWS="$missing" awk '
    { lines[NR] = $0 }
    !found && $0 ~ ENVIRON["HDR"] { found = 1; intable = 1; at = NR; next }
    intable { if ($0 ~ /^\|/) at = NR; else intable = 0 }
    END {
      if (!found) exit 2
      for (i = 1; i <= NR; i++) { print lines[i]; if (i == at) print ENVIRON["ROWS"] }
    }
  ' "$LL_FILE" > "$tmp" || { rm -f "$tmp"; die "No se encontró la tabla de lecciones en $LL_FILE; no se modifica BRAIN.md."; }
  replace_file "$tmp" "$LL_FILE"
}

# ¿lessons_learned.md ya tiene el esquema de 8 columnas (con Ámbito y Estado)?
lessons_schema_ok() {
  [ -f "$LL_FILE" ] || return 1
  # El patrón va por ENVIRON: con -v awk interpretaría las barras invertidas de la regex
  HDR="$BRAIN_HDR_LESSONS" awk -F'|' '$0 ~ ENVIRON["HDR"] { ok = (NF - 2 == 8); exit } END { exit !ok }' "$LL_FILE"
}

# Migra lessons_learned.md del esquema antiguo (6 columnas, sin Estado ni Ámbito) al de 8.
# El Estado se toma de BRAIN.md (7 columnas en el esquema antiguo) o del marcador [OBSOLETA].
# Las lecciones que solo existieran en BRAIN.md se incorporan a la fuente única.
ensure_lessons_schema() {
  [ -f "$LL_FILE" ] || return 0
  lessons_schema_ok && return 0
  grep -qE "$BRAIN_HDR_LESSONS" "$LL_FILE" || return 0
  local tmp
  tmp=$(mktemp)
  local bf=""
  [ -f "$BRAIN_FILE" ] && bf="$BRAIN_FILE"
  BF="$bf" HDR="$BRAIN_HDR_LESSONS" NEWHDR="$BRAIN_LL_HEADER" NEWSEP="$BRAIN_LL_SEP" awk -F'|' '
    function cid(   c) { c = $2; gsub(/[ \t`]/, "", c); return c }
    function strip_end(line) { sub(/[ \t]*\|[ \t]*$/, "", line); return line }
    ENVIRON["BF"] != "" && FILENAME == ENVIRON["BF"] {
      # Primera pasada: BRAIN.md (estado y filas por ID)
      if ($0 ~ /^\|/ && cid() ~ /^LL-[0-9]+$/) {
        st = $(NF-1); gsub(/[ \t`]/, "", st)
        if (st != "ACTIVO" && st != "OBSOLETA") st = "ACTIVO"
        bstate[cid()] = st
        line = $0; sub(/\|[^|]*\|[ \t]*$/, "", line)      # quita la columna Estado
        brow[cid()] = line; order[++nb] = cid()
      }
      next
    }
    {
      if (!inhdr && $0 ~ ENVIRON["HDR"]) { print ENVIRON["NEWHDR"]; inhdr = 1; sep = 1; next }
      if (sep) { sep = 0; if ($0 ~ /^\|[ \t:|-]+$/) { print ENVIRON["NEWSEP"]; intable = 1; next } }
      if ($0 ~ /^\|/ && cid() ~ /^LL-[0-9]+$/) {
        id = cid(); seen[id] = 1
        st = (id in bstate) ? bstate[id] : "ACTIVO"
        line = $0
        if (line ~ /\[OBSOLETA\]/) { st = "OBSOLETA"; sub(/[ \t]*\[OBSOLETA\][ \t]*/, " ", line) }
        print strip_end(line) " | `*` | `" st "` |"
        last_table = 1; next
      }
      if (intable && $0 !~ /^\|/) {
        # Fin de la tabla: añade las lecciones que solo estaban en BRAIN.md
        for (i = 1; i <= nb; i++) if (!(order[i] in seen)) { print strip_end(brow[order[i]]) " | `*` | `" bstate[order[i]] "` |"; seen[order[i]] = 1 }
        intable = 0
      }
      print
    }
    END {
      if (intable) for (i = 1; i <= nb; i++) if (!(order[i] in seen)) print strip_end(brow[order[i]]) " | `*` | `" bstate[order[i]] "` |"
    }
  ' ${bf:+"$bf"} "$LL_FILE" > "$tmp" || { rm -f "$tmp"; die "No se pudo migrar $LL_FILE al esquema nuevo."; }
  replace_file "$tmp" "$LL_FILE"
}

# Regenera el resumen de deuda pendiente de BRAIN.md (§6) a partir de tech_debt.md
debt_sync() {
  [ -f "$DEBT_FILE" ] && [ -f "$BRAIN_FILE" ] || return 0
  grep -qE "$BRAIN_HDR_DEBT" "$DEBT_FILE" || return 0
  grep -qE "$BRAIN_HDR_DEBT" "$BRAIN_FILE" || return 0
  local tmp
  tmp=$(mktemp)
  DF="$DEBT_FILE" HDR="$BRAIN_HDR_DEBT" NEWHDR="$BRAIN_DEBT_HEADER" NEWSEP="$BRAIN_DEBT_SEP" awk -F'|' '
    function trim(x) { gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
    FILENAME == ENVIRON["DF"] {
      id = trim($2); gsub(/`/, "", id)
      if ($0 ~ /^\|/ && id ~ /^TD-[0-9]+$/) {
        pr = trim($(NF-1)); gsub(/`/, "", pr)
        if (pr != "SALDADA") {
          task = trim($3); gsub(/`/, "", task)
          desc = trim($6); work = trim($7); act = trim($8)
          rows[++n] = "| `" id "` | `" task "` | " desc " | " work " | " act " | `" pr "` |"
        }
      }
      next
    }
    !done && $0 ~ ENVIRON["HDR"] {
      print ENVIRON["NEWHDR"]; print ENVIRON["NEWSEP"]
      for (i = 1; i <= n; i++) print rows[i]
      done = 1; skipping = 1; next
    }
    skipping { if ($0 ~ /^\|/) next; skipping = 0 }
    { print }
  ' "$DEBT_FILE" "$BRAIN_FILE" > "$tmp" || { rm -f "$tmp"; die "No se pudo sincronizar deuda en $BRAIN_FILE."; }
  replace_file "$tmp" "$BRAIN_FILE"
}

# Regenera la tabla de lecciones de BRAIN.md a partir de lessons_learned.md (fuente única)
# y sincroniza también la tabla resumen de deuda técnica (§6) si existe tech_debt.md
brain_sync() {
  ensure_lessons_file
  grep -qE "$BRAIN_HDR_LESSONS" "$LL_FILE" || die "No se encontró la tabla de lecciones en $LL_FILE; no se modifica BRAIN.md."
  ensure_lessons_schema
  [ -f "$BRAIN_FILE" ] || return 0
  # Antes de regenerar BRAIN.md, ninguna lección suya puede faltar en la fuente
  adopt_brain_lessons
  if grep -qE "$BRAIN_HDR_LESSONS" "$BRAIN_FILE"; then
    local tmp
    tmp=$(mktemp)
    LF="$LL_FILE" HDR="$BRAIN_HDR_LESSONS" NEWHDR="$BRAIN_LL_HEADER" NEWSEP="$BRAIN_LL_SEP" awk -F'|' '
      FILENAME == ENVIRON["LF"] {
        c = $2; gsub(/[ \t`]/, "", c)
        if ($0 ~ /^\|/ && c ~ /^LL-[0-9]+$/) rows[++n] = $0
        next
      }
      !done && $0 ~ ENVIRON["HDR"] {
        print ENVIRON["NEWHDR"]; print ENVIRON["NEWSEP"]
        for (i = 1; i <= n; i++) print rows[i]
        done = 1; skipping = 1; next
      }
      skipping { if ($0 ~ /^\|/) next; skipping = 0 }
      { print }
    ' "$LL_FILE" "$BRAIN_FILE" > "$tmp" || { rm -f "$tmp"; die "No se pudo sincronizar $BRAIN_FILE."; }
    replace_file "$tmp" "$BRAIN_FILE"
  fi
  debt_sync
}

# Lecciones como "LL-NNN<TAB>CATEGORIA<TAB>problema<TAB>ámbito<TAB>solución<TAB>estado<TAB>causa".
# Lee la fuente única; si aún tiene el esquema antiguo, cae a BRAIN.md (solo lectura, sin migrar).
all_lessons() {
  if lessons_schema_ok; then
    awk -F'|' '
      /^\|/ {
        id = $2; gsub(/[ \t`]/, "", id)
        if (id !~ /^LL-[0-9]+$/) next
        cat = $4; gsub(/[ \t`\[\]]/, "", cat)
        p = $5; gsub(/^[ \t]+|[ \t]+$/, "", p)
        c = $6; gsub(/^[ \t]+|[ \t]+$/, "", c)
        s = $7; gsub(/^[ \t]+|[ \t]+$/, "", s)
        sc = $8; gsub(/`/, "", sc); gsub(/^[ \t]+|[ \t]+$/, "", sc)
        st = $(NF-1); gsub(/[ \t`]/, "", st)
        gsub(/\t/, " ", p); gsub(/\t/, " ", c); gsub(/\t/, " ", s); gsub(/\t/, " ", sc)
        print id "\t" cat "\t" p "\t" sc "\t" s "\t" st "\t" c
      }
    ' "$LL_FILE"
  elif [ -f "$BRAIN_FILE" ]; then
    awk -F'|' '
      /^\|/ {
        id = $2; gsub(/[ \t`]/, "", id)
        if (id !~ /^LL-[0-9]+$/) next
        cat = $4; gsub(/[ \t`\[\]]/, "", cat)
        p = $5; gsub(/^[ \t]+|[ \t]+$/, "", p)
        c = $6; gsub(/^[ \t]+|[ \t]+$/, "", c)
        s = $7; gsub(/^[ \t]+|[ \t]+$/, "", s)
        st = $(NF-1); gsub(/[ \t`]/, "", st)
        gsub(/\t/, " ", p); gsub(/\t/, " ", c); gsub(/\t/, " ", s)
        print id "\t" cat "\t" p "\t*\t" s "\t" st "\t" c
      }
    ' "$BRAIN_FILE"
  fi
}

active_lessons() { all_lessons | awk -F'\t' '$6 == "ACTIVO"'; }

# Devuelve "LL-NNN (problema)" si ya hay una lección activa equivalente; vacío si no.
# Equivalente = mismo texto normalizado (sin tildes, mayúsculas ni puntuación), o bien
# >= 60% de las palabras significativas (4+ letras) en común cuando la nueva tiene 3 o más
similar_lesson() {
  local new_norm
  new_norm=$(printf '%s\n' "$1" | norm_text)
  active_lessons | norm_text | NEW="$new_norm" awk -F'\t' '
    function clean(str) { gsub(/[^a-z0-9]+/, " ", str); gsub(/^ +| +$/, "", str); return str }
    function words(str, arr,    n, i, w, parts, c) {
      n = split(str, parts, " "); c = 0
      for (i = 1; i <= n; i++) { w = parts[i]; if (length(w) >= 4 && !(w in arr)) { arr[w] = 1; c++ } }
      return c
    }
    BEGIN { new = clean(ENVIRON["NEW"]); total = words(new, nw) }
    {
      old = clean($3)
      if (old == new) { print toupper($1) " (" $3 ")"; exit }
      if (total < 3) next
      for (w in ow) delete ow[w]
      words(old, ow); common = 0
      for (w in nw) if (w in ow) common++
      if (common / total >= 0.6) { print toupper($1) " (" $3 ")"; exit }
    }
  '
}

# Detecta el stack activo del proyecto según GLOBAL_STATE.md §2 o variable MAESTRO_STACK
project_stack() {
  if [ -n "${MAESTRO_STACK:-}" ]; then
    printf '%s' "$MAESTRO_STACK"
    return 0
  fi
  [ -f "$STATE_FILE" ] || return 0
  local sline
  sline=$(grep -iE "Stack / Tecnolog|stack-(angular|nextjs|fastapi|nuxt|react-vite|nestjs)" "$STATE_FILE" 2>/dev/null | head -1)
  sline=$(printf '%s' "$sline" | norm_text)
  case "$sline" in
    *nuxt*)                          echo nuxt ;;
    *react-vite*|*react*vite*)       echo react-vite ;;
    *nestjs*)                        echo nestjs ;;
    *nextjs*|*next*)                 echo nextjs ;;
    *fastapi*)                       echo fastapi ;;
    *angular*)                       echo angular ;;
    *)                               echo "" ;;
  esac
}

# Lecciones activas relevantes, como "LL-NNN<TAB>CAT<TAB>problema<TAB>motivo<TAB>solución<TAB>reincidencias".
#   $1 = categoría (puede ir vacía)   $2 = texto de la tarea (descripción + criterios)
#   $3 = rutas, una por línea (pueden ir vacías)
# Motivos, por prioridad: el ámbito de la lección cubre una ruta; es de la categoría del
# agente; comparte 2 o más palabras significativas (5+ letras) con la tarea.
relevant_lessons() {
  local lessons norm recs stk
  lessons=$(active_lessons)
  [ -n "$lessons" ] || return 0
  norm=$(printf '%s\n' "$lessons" | norm_text)
  recs=$(all_recurrences)
  stk=$(project_stack)
  LESSONS="$lessons" NORM="$norm" RECS="$recs" CURR_STACK="$stk" CAT="$1" PATHS="$3" \
  TASKTXT="$(printf '%s\n' "$2" | norm_text)" awk '
    function words(str, arr,    n, i, w, parts, c) {
      gsub(/[^a-z0-9]+/, " ", str); n = split(str, parts, " "); c = 0
      for (i = 1; i <= n; i++) { w = parts[i]; if (length(w) >= 5 && !(w in arr)) { arr[w] = 1; c++ } }
      return c
    }
    function glob2re(g,    r, i, ch) {
      r = ""
      for (i = 1; i <= length(g); i++) {
        ch = substr(g, i, 1)
        if (ch == "*") r = r ".*"
        else if (ch == "?") r = r "."
        else if (index("\\.[]()+^$|{}", ch)) r = r "\\" ch
        else r = r ch
      }
      return r
    }
    function scope_hit(scope,    n, i, j, gl, parts, re) {
      n = split(scope, parts, ",")
      for (i = 1; i <= n; i++) {
        gl = parts[i]; gsub(/^[ \t`]+|[ \t`]+$/, "", gl)
        if (gl == "" || gl == "*") continue
        re = "(^|/)" glob2re(gl) (gl ~ /\/$/ ? ".*" : "") "$"
        for (j = 1; j <= np; j++) if (paths[j] != "" && paths[j] ~ re) return gl
      }
      return ""
    }
    BEGIN {
      nl = split(ENVIRON["LESSONS"], raw, "\n"); split(ENVIRON["NORM"], nrm, "\n")
      np = split(ENVIRON["PATHS"], paths, "\n"); cat = ENVIRON["CAT"]
      cur_stk = tolower(ENVIRON["CURR_STACK"])
      nr = split(ENVIRON["RECS"], rlines, "\n")
      for (r = 1; r <= nr; r++) {
        if (rlines[r] == "") continue
        split(rlines[r], rf, "\t")
        reccount[rf[1]]++
      }
      words(ENVIRON["TASKTXT"], tw)
      for (k = 1; k <= nl; k++) {
        if (raw[k] == "") continue
        split(raw[k], f, "\t"); split(nrm[k], g, "\t")

        # Filtro de stack si la categoría incluye etiqueta :stack (ej. BACKEND:fastapi)
        stk_tag = ""
        if (index(f[2], ":") > 0) {
          split(f[2], cparts, ":")
          stk_tag = tolower(cparts[2]); gsub(/[^a-z0-9_-]/, "", stk_tag)
        }
        if (stk_tag != "" && cur_stk != "" && stk_tag != cur_stk) continue

        reason = ""
        hit = scope_hit(f[4])
        if (hit != "") reason = "ámbito " hit
        else if (cat != "" && (f[2] == cat || f[2] ~ ("^" cat ":"))) reason = "categoría " cat
        else {
          for (w in ow) delete ow[w]
          words(g[3] " " g[5], ow); c = 0
          for (w in tw) if (w in ow) c++
          if (c >= 2) reason = "palabras en común con la tarea"
        }
        rc = (f[1] in reccount) ? reccount[f[1]] : 0
        if (reason != "") print f[1] "\t" f[2] "\t" f[3] "\t" reason "\t" f[5] "\t" rc
      }
    }
  '
}

# Deudas pendientes (no SALDADA) como "TD-NNN<TAB>TASK<TAB>descripción<TAB>prioridad"
pending_debts() {
  [ -f "$DEBT_FILE" ] || return 0
  awk -F'|' '
    /^\|/ {
      id = $2; gsub(/[ \t`]/, "", id)
      if (id !~ /^TD-[0-9]+$/) next
      pr = $(NF-1); gsub(/[ \t`]/, "", pr)
      if (pr == "SALDADA") next
      t = $3; gsub(/[ \t`]/, "", t)
      d = $6; gsub(/^[ \t]+|[ \t]+$/, "", d)
      print id "\t" t "\t" d "\t" pr
    }
  ' "$DEBT_FILE"
}

# Busca términos (todos deben aparecer; sin distinguir tildes ni mayúsculas) en lecciones,
# gotchas/glosario de BRAIN.md y deudas. Imprime una línea por coincidencia.
brain_search() {
  local corpus norm terms
  terms=$(printf '%s\n' "$*" | norm_text)
  case "$terms" in *[![:space:]]*) ;; *) return 0 ;; esac
  corpus=$(
    all_lessons | awk -F'\t' '{ print "LECCION\t" $1 " [" $2 "] " $3 " → " $5 " (ámbito: " $4 ($6 == "ACTIVO" ? "" : "; " $6) ")" }'
    if [ -f "$BRAIN_FILE" ]; then
      awk -F'|' '/^\|[ \t]*\*\*/ { out = ""; for (i = 2; i < NF; i++) { c = $i; gsub(/^[ \t]+|[ \t]+$/, "", c); out = out (i > 2 ? " · " : "") c } print "GOTCHA\t" out }' "$BRAIN_FILE"
    fi
    if [ -f "$DEBT_FILE" ]; then
      awk -F'|' '/^\|/ { id = $2; gsub(/[ \t`]/, "", id); if (id !~ /^TD-[0-9]+$/) next; d = $6; gsub(/^[ \t]+|[ \t]+$/, "", d); a = $8; gsub(/^[ \t]+|[ \t]+$/, "", a); pr = $(NF-1); gsub(/[ \t`]/, "", pr); t = $3; gsub(/[ \t`]/, "", t); print "DEUDA\t" id " (" t ", " pr ") " d " → " a }' "$DEBT_FILE"
    fi
  )
  [ -n "$corpus" ] || return 0
  norm=$(printf '%s\n' "$corpus" | norm_text)
  CORPUS="$corpus" NORM="$norm" TERMS="$terms" awk '
    BEGIN {
      n = split(ENVIRON["CORPUS"], raw, "\n"); split(ENVIRON["NORM"], nrm, "\n")
      nt = split(ENVIRON["TERMS"], t, /[ \t]+/)
      for (k = 1; k <= n; k++) {
        ok = 1
        for (i = 1; i <= nt; i++) if (t[i] != "" && index(nrm[k], t[i]) == 0) { ok = 0; break }
        if (ok && raw[k] != "") { tab = index(raw[k], "\t"); printf "  [%s] %s\n", substr(raw[k], 1, tab - 1), substr(raw[k], tab + 1) }
      }
    }
  '
}

# ------------------------------------------------------------------------------
# Reincidencias, salud y métricas
# ------------------------------------------------------------------------------
BRAIN_REC_HEADER='| Fecha | Tarea | Lección | Motivo del rechazo |'
BRAIN_REC_SEP='| :---: | :---: | :---: | :--- |'

rec_file() { printf '%s' "$(dirname "$LL_FILE")/recurrences.md"; }

# Lección activa que un motivo de rechazo repite: "LL-NNN<TAB>problema", o vacío.
# Coincide si el motivo cita el ID de una lección activa, o si comparte 3 o más palabras
# significativas (5+ letras, sin palabras genéricas y agrupando plurales simples) con su
# problema, causa raíz o antídoto (TD-004).
recurrence_for() {
  local lessons norm
  lessons=$(active_lessons)
  [ -n "$lessons" ] || return 0
  norm=$(printf '%s\n' "$lessons" | norm_text)
  LESSONS="$lessons" NORM="$norm" REASON="$(printf '%s\n' "$1" | norm_text)" awk '
    function stem(w) {
      if (length(w) >= 7 && w ~ /(ad|or|on|al|ar|er|an|en|in|un|iz|uz)es$/) sub(/es$/, "", w)
      else if (length(w) >= 6 && w ~ /s$/ && w !~ /(ss|is|us)$/) sub(/s$/, "", w)
      return w
    }
    function words(str, arr,    n, i, w, parts, c) {
      gsub(/[^a-z0-9]+/, " ", str); n = split(str, parts, " "); c = 0
      for (i = 1; i <= n; i++) {
        w = parts[i]
        if (length(w) >= 5 && !(w in stop)) {
          w = stem(w)
          if (!(w in stop) && !(w in arr)) { arr[w] = 1; c++ }
        }
      }
      return c
    }
    BEGIN {
      ns = split("antes despues cuando donde sobre entre desde hasta todos todas todo cada tiene tienen hacer hacia falta faltan falla fallan fallo fallos error errores tests prueba pruebas suite completa completo ejecutar ejecuta enviar envia valida validar codigo archivo archivos tarea tareas debe deben puede pueden usar usando siempre nunca nuevo nueva nuevos nuevas mismo misma aunque porque mientras tambien solo cualquier correcto correcta incorrecto incorrecta criterio criterios aceptacion cumple cumplen funciona funcionan devuelve devolver salida entrada valor valores datos sistema proyecto script scripts comando comandos linea lineas", sw, " ")
      for (i = 1; i <= ns; i++) stop[stem(sw[i])] = 1
      nl = split(ENVIRON["LESSONS"], raw, "\n"); split(ENVIRON["NORM"], nrm, "\n")
      reason = ENVIRON["REASON"]; words(reason, rw)
      best = 0; bi = 0
      for (k = 1; k <= nl; k++) {
        if (raw[k] == "") continue
        split(raw[k], f, "\t"); split(nrm[k], g, "\t")
        if (reason ~ ("(^|[^a-z0-9])" tolower(f[1]) "([^0-9]|$)")) { bi = k; best = 99; break }
        for (w in ow) delete ow[w]
        words(g[3] " " g[5] " " g[7], ow); c = 0
        for (w in rw) if (w in ow) c++
        if (c >= 3 && c > best) { best = c; bi = k }
      }
      if (bi) { split(raw[bi], f, "\t"); print f[1] "\t" f[3] }
    }
  '
}

# Anota una reincidencia en .agents/brain/recurrences.md (lo crea si falta)
record_recurrence() {
  local file task="$1" lesson="$2" reason="$3" tmp
  file=$(rec_file)
  [ -d "$file" ] && return 1
  if [ ! -f "$file" ]; then
    mkdir -p "$(dirname "$file")" 2>/dev/null || return 1
    { : > "$file"; } 2>/dev/null || return 1
    printf '%s\n\n%s\n\n%s\n%s\n' '# Reincidencias (Recurrences)' \
      '> **Propósito**: rechazos de QA cuyo motivo ya estaba cubierto por una lección activa. Lo escribe `task.sh reject`; una lección con reincidencias no está llegando a tiempo al agente: revisa su ámbito (`task.sh brain scope`) o su antídoto.' \
      "$BRAIN_REC_HEADER" "$BRAIN_REC_SEP" > "$file"
  fi
  { printf '| %s | `%s` | `%s` | %s |\n' "$(date +%Y-%m-%d)" "$task" "$lesson" "$(printf '%s' "$reason" | tr '\n\r\t|' '   /')" >> "$file"; } 2>/dev/null || return 1
}

# Reincidencias como "LL-NNN<TAB>TASK"
all_recurrences() {
  local file
  file=$(rec_file)
  [ -f "$file" ] || return 0
  awk -F'|' '/^\|/ { l = $4; gsub(/[ \t`]/, "", l); t = $3; gsub(/[ \t`]/, "", t); if (l ~ /^LL-[0-9]+$/) print l "\t" t }' "$file"
}

# Valida el cerebro. Imprime "ERROR: ..." o "AVISO: ..." por línea; devuelve 1 si hay errores.
brain_doctor() {
  local out="" rc=0
  if [ ! -f "$LL_FILE" ]; then
    [ -f "$BRAIN_FILE" ] && grep -qE '^\|[ \t]*`?LL-[0-9]+' "$BRAIN_FILE" \
      && out="AVISO: falta .agents/brain/lessons_learned.md y BRAIN.md tiene lecciones; ejecuta: task.sh brain sync"
    [ -n "$out" ] && printf '%s\n' "$out"
    return 0
  fi
  if ! grep -qE "$BRAIN_HDR_LESSONS" "$LL_FILE"; then
    printf '%s\n' "ERROR: lessons_learned.md no tiene la tabla de lecciones (cabecera '| ID | Fecha | Categoría | ...'); si el archivo está vacío o dañado, bórralo y ejecuta: task.sh brain sync (lo recrea y recupera las lecciones de BRAIN.md)"
    return 1
  fi
  if ! lessons_schema_ok; then
    printf '%s\n' "AVISO: lessons_learned.md usa el esquema antiguo (sin Ámbito ni Estado); ejecuta: task.sh brain sync"
    return 0
  fi
  out=$(awk -F'|' '
    function trim(x) { gsub(/^[ \t`]+|[ \t`]+$/, "", x); return x }
    /^\|/ {
      id = trim($2)
      if (id !~ /^LL-[0-9]+$/) next
      n++
      if (id in seen) print "ERROR: " id " está duplicada en lessons_learned.md"
      seen[id] = 1
      if (NF - 2 != 8) { print "ERROR: " id " tiene " (NF - 2) " columnas en lugar de 8 (¿un | sin escapar en el texto?)"; next }
      st = trim($(NF-1))
      if (st != "ACTIVO" && st != "OBSOLETA") print "ERROR: " id " tiene un Estado inválido: \"" st "\" (ACTIVO u OBSOLETA)"
      if (trim($5) == "") print "ERROR: " id " no tiene problema"
      if (trim($8) == "") print "ERROR: " id " no tiene ámbito (usa * si es general)"
      if (st == "ACTIVO") {
        if (trim($6) == "" || trim($6) == "Por documentar") print "AVISO: " id " no documenta la causa raíz"
        if (trim($7) == "" || trim($7) == "Por documentar") print "AVISO: " id " no documenta la solución"
      }
    }
  ' "$LL_FILE")
  if [ -f "$BRAIN_FILE" ] && grep -qE "$BRAIN_HDR_LESSONS" "$BRAIN_FILE"; then
    if [ "$(grep -E '^\|[ \t]*`?LL-[0-9]+' "$BRAIN_FILE")" != "$(grep -E '^\|[ \t]*`?LL-[0-9]+' "$LL_FILE")" ]; then
      out="${out}${out:+$'\n'}ERROR: la tabla de lecciones de BRAIN.md no coincide con lessons_learned.md; ejecuta: task.sh brain sync"
    fi
  fi
  if [ -f "$DEBT_FILE" ]; then
    if ! grep -qE "$BRAIN_HDR_DEBT" "$DEBT_FILE"; then
      out="${out}${out:+$'\n'}ERROR: tech_debt.md no tiene la tabla de deuda técnica (cabecera '| ID | Tarea Vinculada | ...')"
    else
      out="${out}${out:+$'\n'}$(awk -F'|' '
        function trim(x) { gsub(/^[ \t`]+|[ \t`]+$/, "", x); return x }
        /^\|/ {
          id = trim($2)
          if (id !~ /^TD-[0-9]+$/) next
          if (id in seen) print "ERROR: " id " está duplicada en tech_debt.md"
          seen[id] = 1
          pr = trim($(NF-1))
          if (pr != "ALTA" && pr != "MEDIA" && pr != "BAJA" && pr != "SALDADA") print "ERROR: " id " tiene una prioridad inválida: \"" pr "\""
          if (trim($3) !~ /^TASK-[0-9]+$/) print "AVISO: " id " no está vinculada a una TASK-XXX"
        }
      ' "$DEBT_FILE")"
      if [ -f "$BRAIN_FILE" ] && grep -qE "$BRAIN_HDR_DEBT" "$BRAIN_FILE"; then
        local td_pend td_brain
        td_pend=$(pending_debts | awk -F'\t' '{ print $1 ":" $4 }' | sort)
        td_brain=$(awk -F'|' '/^\|/ { id = $2; gsub(/[ \t`]/, "", id); if (id ~ /^TD-[0-9]+$/) { pr = $(NF-1); gsub(/[ \t`]/, "", pr); print id ":" pr } }' "$BRAIN_FILE" | sort)
        if [ "$td_pend" != "$td_brain" ]; then
          out="${out}${out:+$'\n'}ERROR: la tabla de deuda técnica de BRAIN.md no coincide con tech_debt.md; ejecuta: task.sh brain sync"
        fi
      fi
    fi
  fi
  out=$(printf '%s\n' "$out" | grep -v '^$' || true)
  [ -n "$out" ] && printf '%s\n' "$out"
  printf '%s\n' "$out" | grep -q '^ERROR' && rc=1
  return $rc
}

# Resumen numérico del cerebro (orden estable: no depende del "for in" de awk)
brain_stats() {
  local lessons recs
  lessons=$(all_lessons)
  recs=$(all_recurrences)
  LESSONS="$lessons" awk '
    BEGIN {
      n = split(ENVIRON["LESSONS"], l, "\n")
      for (i = 1; i <= n; i++) { if (l[i] == "") continue; split(l[i], f, "\t"); total++; if (f[6] == "ACTIVO") { act++; if (f[4] == "*") general++ } else obs++ }
      printf "Lecciones: %d (%d activas, %d obsoletas)\n", total, act, obs
      if (act) printf "  Con ámbito de rutas: %d · generales (*): %d\n", act - general, general
    }'
  printf '%s\n' "$lessons" | awk -F'\t' '$6 == "ACTIVO" { print $2 }' | sort | uniq -c | awk '{ printf "  [%s] %d\n", $2, $1 }'
  printf 'Reincidencias: %d\n' "$(printf '%s\n' "$recs" | grep -c . || true)"
  printf '%s\n' "$recs" | awk -F'\t' 'NF { print $1 }' | sort | uniq -c | sort -rn | awk '{ printf "  %s: %d\n", $2, $1 }'
  if [ -f "$DEBT_FILE" ]; then
    awk -F'|' '/^\|/ { id = $2; gsub(/[ \t`]/, "", id); if (id ~ /^TD-[0-9]+$/) { p = $(NF-1); gsub(/[ \t`]/, "", p); if (p == "SALDADA") paid++; else { pend++; if (p == "ALTA") high++ } } }
      END { printf "Deuda técnica: %d pendiente (%d de prioridad ALTA), %d saldada\n", pend, high, paid }' "$DEBT_FILE"
  fi
}

# Identifica los hotspots de riesgo (rutas con mayor concentración de lecciones y reincidencias)
brain_hotspots() {
  local lessons recs
  lessons=$(active_lessons)
  recs=$(all_recurrences)
  [ -n "$lessons" ] || { printf '%s\n' "No hay lecciones activas."; return 0; }
  LESSONS="$lessons" RECS="$recs" awk '
    BEGIN {
      split(ENVIRON["RECS"], rlines, "\n")
      for (i in rlines) {
        if (rlines[i] == "") continue
        split(rlines[i], rf, "\t")
        reccount[rf[1]]++
      }
      nl = split(ENVIRON["LESSONS"], llines, "\n")
      for (k = 1; k <= nl; k++) {
        if (llines[k] == "") continue
        split(llines[k], lf, "\t")
        id = lf[1]; scope = lf[4]
        if (scope == "" || scope == "*") continue
        nparts = split(scope, parts, ",")
        rc = (id in reccount) ? reccount[id] : 0
        for (p = 1; p <= nparts; p++) {
          gl = parts[p]; gsub(/^[ \t`]+|[ \t`]+$/, "", gl)
          if (gl == "" || gl == "*") continue
          globs[gl]++
          recs_by_glob[gl] += rc
        }
      }
      for (g in globs) {
        score = (globs[g] * 2) + (recs_by_glob[g] * 3)
        printf "%d\t%s\t%d\t%d\n", score, g, globs[g], recs_by_glob[g]
      }
    }
  ' | sort -rn -k1,1 | head -10 | awk -F'\t' '
    BEGIN { printf "🔥 Hotspots de Riesgo del Código (rutas con mayor concentración de lecciones):\n" }
    {
      score = $1; path = $2; count = $3; recs = $4
      level = "[MEDIO]"
      if (score >= 12 || recs >= 2) level = "[RIESGO CRÍTICO]"
      else if (score >= 6 || recs >= 1) level = "[RIESGO ALTO]"
      printf "  %2d. %-35s · %d lecciones · %d reincidencias  %s\n", NR, path, count, recs, level
    }
    END {
      if (NR == 0) printf "  Sin hotspots de riesgo definidos en ámbitos.\n"
    }
  '
}

# Registra una preferencia del desarrollador en .agents/brain/preferences.md
brain_prefer() {
  local cat="$1" rule="$2"
  [ -n "$cat" ] && [ -n "$rule" ] || die "Uso: task.sh prefer \"<categoría>\" \"<regla>\""
  local pref_file="$(dirname "$LL_FILE")/preferences.md"
  local tpl="$(dirname "$LL_FILE")/../templates/preferences_template.md"
  if [ ! -f "$pref_file" ]; then
    mkdir -p "$(dirname "$pref_file")"
    if [ -f "$tpl" ]; then
      cp "$tpl" "$pref_file"
    else
      printf '%s\n\n' '# Preferencias del Desarrollador y Convenciones del Proyecto (Preferences)' > "$pref_file"
    fi
  fi
  # Comprobar si la regla ya existe (mismo texto normalizado)
  local r_norm
  r_norm=$(printf '%s\n' "$rule" | norm_text)
  if norm_text < "$pref_file" | grep -Fq "$r_norm"; then
    say "ℹ️  La preferencia ya está registrada en preferences.md."
    return 0
  fi
  # Añadir bajo la categoría o crear la sección correspondiente
  local tmp; tmp=$(mktemp)
  python3 - "$pref_file" "$tmp" "$cat" "$rule" <<'PY'
import sys, re, pathlib

pref_path = pathlib.Path(sys.argv[1])
tmp_path = pathlib.Path(sys.argv[2])
cat = sys.argv[3].strip()
rule = sys.argv[4].strip()

content = pref_path.read_text(encoding="utf-8")
cat_pattern = re.compile(rf"^##\s+([0-9]+\.\s*)?{re.escape(cat)}\b", re.IGNORECASE | re.MULTILINE)

m = cat_pattern.search(content)
if m:
    pos = m.end()
    next_sec = re.search(r"^##\s+", content[pos:], re.MULTILINE)
    if next_sec:
        insert_at = pos + next_sec.start()
        prefix = content[:insert_at].rstrip()
        suffix = content[insert_at:]
        new_content = f"{prefix}\n- {rule}\n\n{suffix.lstrip()}"
    else:
        new_content = f"{content.rstrip()}\n- {rule}\n"
else:
    sections = re.findall(r"^##\s+([0-9]+)\.", content, re.MULTILINE)
    next_num = len(sections) + 1 if sections else ""
    header = f"## {next_num}. {cat}" if next_num else f"## {cat}"
    new_content = f"{content.rstrip()}\n\n---\n\n{header}\n- {rule}\n"

tmp_path.write_text(new_content, encoding="utf-8")
PY
  replace_file "$tmp" "$pref_file"
  say "✅ Preferencia registrada en [$cat]: $rule"
}

# Linter activo de antipatrones históricos del cerebro
brain_lint() {
  local target_paths=("$@")
  local violations=0
  local files=()

  if [ ${#target_paths[@]} -eq 0 ]; then
    while IFS= read -r f; do
      [ -f "$f" ] && files+=("$f")
    done < <(git ls-files 2>/dev/null || find . -type f -not -path '*/.*/*')
  else
    for p in "${target_paths[@]}"; do
      if [ -f "$p" ]; then
        files+=("$p")
      elif [ -d "$p" ]; then
        while IFS= read -r f; do
          [ -f "$f" ] && files+=("$f")
        done < <(find "$p" -type f)
      fi
    done
  fi

  [ ${#files[@]} -gt 0 ] || { say "ℹ️  No hay archivos que auditar para brain lint."; return 0; }

  for f in "${files[@]}"; do
    case "$f" in
      *.sh)
        # Excluir archivos de prueba y el propio linter que citan los patrones como strings de test
        local bn
        bn="$(basename "$f")"
        if [ "$bn" = "test-scripts.sh" ] || [ "$bn" = "brain-lib.sh" ] || [ "$bn" = "task.sh" ]; then
          continue
        fi

        # LL-001: awk BSD no reconoce \s
        local m_ll001
        m_ll001=$(grep -nE "awk .*\\\\s|awk '.*\\\\s" "$f" 2>/dev/null || true)
        if [ -n "$m_ll001" ]; then
          say "❌ [LL-001] Uso de '\\s' en awk no portable en $f:"
          printf '%s\n' "$m_ll001" | sed 's/^/     /'
          say "   Antídoto: Usar clases POSIX [[:space:]] o [ \\t] para compatibilidad entre macOS y Linux."
          violations=$((violations + 1))
        fi

        # LL-007: sed y/// no normaliza en locale C
        local m_ll007
        m_ll007=$(grep -nE "sed .*y/[a-zA-Zá-úÁ-Ú]" "$f" 2>/dev/null || true)
        if [ -n "$m_ll007" ]; then
          say "❌ [LL-007] Uso de transliteración 'sed y///' no portable en $f:"
          printf '%s\n' "$m_ll007" | sed 's/^/     /'
          say "   Antídoto: Usar python3 unicodedata o sustituciones explícitas sed -e 's/.../.../g'."
          violations=$((violations + 1))
        fi

        # LL-012: awk FNR==NR sin validación de archivo no vacío
        local m_ll012
        m_ll012=$(grep -nE "FNR[[:space:]]*==[[:space:]]*NR" "$f" 2>/dev/null || true)
        if [ -n "$m_ll012" ]; then
          say "❌ [LL-012] Uso de 'FNR==NR' propenso a fallos con primer archivo vacío en $f:"
          printf '%s\n' "$m_ll012" | sed 's/^/     /'
          say "   Antídoto: Usar FILENAME==ENVIRON[...] o validar archivo no vacío previamente."
          violations=$((violations + 1))
        fi

        # LL-016: trap de INT/TERM sin exit
        local m_ll016
        m_ll016=$(awk '
          /trap.*INT/ && !/exit 130/ && !/kill/ && !/return/ { print NR ":" $0 }
          /trap.*TERM/ && !/exit 143/ && !/kill/ && !/return/ { print NR ":" $0 }
        ' "$f" 2>/dev/null || true)
        if [ -n "$m_ll016" ]; then
          say "❌ [LL-016] Trap de INT o TERM sin código de salida exit 130/143 en $f:"
          printf '%s\n' "$m_ll016" | sed 's/^/     /'
          say "   Antídoto: Separar trap de EXIT del trap de INT/TERM con exit 130/143."
          violations=$((violations + 1))
        fi
        ;;
    esac
  done

  if [ "$violations" -gt 0 ]; then
    say "❌ [brain lint] Se encontraron $violations violación(es) de antipatrones aprendidos."
    return 1
  fi

  say "✅ [brain lint] 0 violaciones de antipatrones del cerebro detectadas."
  return 0
}
