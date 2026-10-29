#!/usr/bin/env bash
# ==============================================================================
# Escáner de Secretos (fuente única para el hook pre-commit y la CI)
# ==============================================================================
# Uso:
#   scan-secrets.sh --staged   Revisa solo las líneas añadidas en el commit (pre-commit)
#   scan-secrets.sh --all      Revisa todos los archivos versionados (CI)
#
# Para aceptar una línea concreta (ej. una clave de ejemplo en documentación),
# añade el comentario `secret-scan:allow` en esa misma línea.
# ==============================================================================

MODE="${1:---staged}"

# Patrones de credenciales reales (exigen longitud mínima para evitar falsos positivos como "task-")
PATTERNS='sk-(ant-|proj-|live_|test_)?[A-Za-z0-9_-]{20,}'
PATTERNS="$PATTERNS"'|ghp_[A-Za-z0-9]{36}|gh[ousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{40,}'
PATTERNS="$PATTERNS"'|(sk|rk)_(live|test)_[0-9A-Za-z]{24,}|whsec_[0-9A-Za-z]{24,}'
PATTERNS="$PATTERNS"'|AKIA[0-9A-Z]{16}'
PATTERNS="$PATTERNS"'|AIza[0-9A-Za-z_-]{35}'
PATTERNS="$PATTERNS"'|xox[baprs]-[A-Za-z0-9-]{10,}'
PATTERNS="$PATTERNS"'|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'

# Archivos .env reales (se permiten .env.example / .env.template / .env.sample)
ENV_FILE_RX='(^|/)\.env($|\.)'
ENV_ALLOWED_RX='\.(example|template|sample)$'

FOUND=0

report() {
  echo "❌ $1"
  FOUND=1
}

case "$MODE" in
  --staged)
    FILES=$(git diff --cached --name-only --diff-filter=ACMR)
    ;;
  --all)
    FILES=$(git ls-files)
    ;;
  *)
    echo "Uso: $0 [--staged|--all]"
    exit 2
    ;;
esac

while IFS= read -r f; do
  [ -z "$f" ] && continue

  if printf '%s' "$f" | grep -qE "$ENV_FILE_RX" && ! printf '%s' "$f" | grep -qE "$ENV_ALLOWED_RX"; then
    report "Archivo de entorno con credenciales: $f (no debe versionarse)"
    continue
  fi

  if [ "$MODE" = "--staged" ]; then
    CONTENT=$(git diff --cached -U0 --no-color -- "$f" | grep -E '^\+' | grep -vE '^\+\+\+ ')
  else
    [ -f "$f" ] || continue
    grep -Iq . "$f" 2>/dev/null || continue   # omitir binarios
    CONTENT=$(cat "$f")
  fi

  HITS=$(printf '%s\n' "$CONTENT" | grep -nE -- "$PATTERNS" | grep -v 'secret-scan:allow' || true)
  if [ -n "$HITS" ]; then
    report "Posible secreto en $f:"
    # Mostrar solo el inicio de la coincidencia, nunca el secreto completo
    printf '%s\n' "$HITS" | grep -oE -- "$PATTERNS" | cut -c1-12 | sed 's/^/     -> /; s/$/…/'
  fi
done <<< "$FILES"

if [ $FOUND -ne 0 ]; then
  echo ""
  echo "   Mueve las credenciales a .env (ignorado por git) y referencia variables de entorno."
  echo "   Si es un falso positivo, añade 'secret-scan:allow' en esa línea."
  exit 1
fi

echo "✅ Escaneo de secretos sin hallazgos."
exit 0
