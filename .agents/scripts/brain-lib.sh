#!/usr/bin/env bash
# ==============================================================================
# Biblioteca del Cerebro (memoria a largo plazo): la cargan task.sh y brain-context.sh
# ==============================================================================
# Fuente única de lecciones: .agents/brain/lessons_learned.md, con 8 columnas:
#   | ID | Fecha | Categoría | Problema | Causa Raíz | Solución | Ámbito | Estado |
# La tabla de lecciones de BRAIN.md es una copia generada con brain_sync: no se edita a mano.
#
# Ámbito: globs de rutas separados por comas (ej. `.agents/scripts/*.sh,tests/*.sh`) a las
# que aplica la lección; `*` = general (no ligada a archivos concretos).
#
# Requiere definidos: BRAIN_FILE, LL_FILE, DEBT_FILE, STATE_FILE y las funciones die y
# replace_file. Compatible con bash 3.2 y awk/sed BSD y GNU; python3 es opcional.
# ==============================================================================

BRAIN_HDR_LESSONS='^\|[ \t]*ID[ \t]*\|[ \t]*Fecha[ \t]*\|[ \t]*Categor'
BRAIN_LL_HEADER='| ID | Fecha | Categoría | Problema Encontrado | Causa Raíz | Solución Aplicada (Antídoto) | Ámbito | Estado |'
BRAIN_LL_SEP='| :---: | :---: | :---: | :--- | :--- | :--- | :--- | :---: |'

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

# Regenera la tabla de lecciones de BRAIN.md a partir de lessons_learned.md (fuente única)
brain_sync() {
  [ -f "$BRAIN_FILE" ] && [ -f "$LL_FILE" ] || return 0
  ensure_lessons_schema
  grep -qE "$BRAIN_HDR_LESSONS" "$BRAIN_FILE" || return 0
  local tmp
  tmp=$(mktemp)
  HDR="$BRAIN_HDR_LESSONS" NEWHDR="$BRAIN_LL_HEADER" NEWSEP="$BRAIN_LL_SEP" awk -F'|' '
    FNR == NR {
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
}

# Lecciones como "LL-NNN<TAB>CATEGORIA<TAB>problema<TAB>ámbito<TAB>solución<TAB>estado".
# Lee la fuente única; si aún tiene el esquema antiguo, cae a BRAIN.md (solo lectura, sin migrar).
all_lessons() {
  if lessons_schema_ok; then
    awk -F'|' '
      /^\|/ {
        id = $2; gsub(/[ \t`]/, "", id)
        if (id !~ /^LL-[0-9]+$/) next
        cat = $4; gsub(/[ \t`\[\]]/, "", cat)
        p = $5; gsub(/^[ \t]+|[ \t]+$/, "", p)
        s = $7; gsub(/^[ \t]+|[ \t]+$/, "", s)
        sc = $8; gsub(/[ \t`]/, "", sc)
        st = $(NF-1); gsub(/[ \t`]/, "", st)
        print id "\t" cat "\t" p "\t" sc "\t" s "\t" st
      }
    ' "$LL_FILE"
  elif [ -f "$BRAIN_FILE" ]; then
    awk -F'|' '
      /^\|/ {
        id = $2; gsub(/[ \t`]/, "", id)
        if (id !~ /^LL-[0-9]+$/) next
        cat = $4; gsub(/[ \t`\[\]]/, "", cat)
        p = $5; gsub(/^[ \t]+|[ \t]+$/, "", p)
        s = $7; gsub(/^[ \t]+|[ \t]+$/, "", s)
        st = $(NF-1); gsub(/[ \t`]/, "", st)
        print id "\t" cat "\t" p "\t*\t" s "\t" st
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

# Lecciones activas relevantes, como "LL-NNN<TAB>CAT<TAB>problema<TAB>motivo<TAB>solución".
#   $1 = categoría (puede ir vacía)   $2 = texto de la tarea (descripción + criterios)
#   $3 = rutas, una por línea (pueden ir vacías)
# Motivos, por prioridad: el ámbito de la lección cubre una ruta; es de la categoría del
# agente; comparte 2 o más palabras significativas (5+ letras) con la tarea.
relevant_lessons() {
  local lessons norm
  lessons=$(active_lessons)
  [ -n "$lessons" ] || return 0
  norm=$(printf '%s\n' "$lessons" | norm_text)
  LESSONS="$lessons" NORM="$norm" CAT="$1" PATHS="$3" \
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
        re = "(^|/)" glob2re(gl) "$"
        for (j = 1; j <= np; j++) if (paths[j] != "" && paths[j] ~ re) return gl
      }
      return ""
    }
    BEGIN {
      nl = split(ENVIRON["LESSONS"], raw, "\n"); split(ENVIRON["NORM"], nrm, "\n")
      np = split(ENVIRON["PATHS"], paths, "\n"); cat = ENVIRON["CAT"]
      words(ENVIRON["TASKTXT"], tw)
      for (k = 1; k <= nl; k++) {
        if (raw[k] == "") continue
        split(raw[k], f, "\t"); split(nrm[k], g, "\t")
        reason = ""
        hit = scope_hit(f[4])
        if (hit != "") reason = "ámbito " hit
        else if (cat != "" && f[2] == cat) reason = "categoría " cat
        else {
          for (w in ow) delete ow[w]
          words(g[3] " " g[5], ow); c = 0
          for (w in tw) if (w in ow) c++
          if (c >= 2) reason = "palabras en común con la tarea"
        }
        if (reason != "") print f[1] "\t" f[2] "\t" f[3] "\t" reason "\t" f[5]
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
