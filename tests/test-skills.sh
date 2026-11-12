#!/usr/bin/env bash
# ==============================================================================
# Linter de Calidad y Estructura de Skills (SKILL MAESTRO)
# Uso: bash tests/test-skills.sh
# Audita metadatos YAML, integridad de enlaces relativos y secciones estándar.
# ==============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0
TOTAL=0

red()   { printf "\033[31m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }

printf "=== Auditando estructura y calidad de skills (.agents/skills/) ===\n\n"

for skill_file in "$ROOT"/.agents/skills/*/SKILL.md; do
  [ -f "$skill_file" ] || continue
  TOTAL=$((TOTAL + 1))
  skill_dir="$(dirname "$skill_file")"
  skill_name="$(basename "$skill_dir")"
  file_errors=0

  # 1. Frontmatter YAML básico
  if ! head -n 1 "$skill_file" | tr -d '\r' | grep -qE "^---[[:space:]]*$"; then
    red "  ❌ [$skill_name] Falta delimitador inicial '---' en YAML frontmatter"
    file_errors=$((file_errors + 1))
  fi

  if ! awk '{ sub(/\r$/, "") } NR > 1 && /^---[ \t]*$/ { f=1; exit } END { exit !f }' "$skill_file"; then
    red "  ❌ [$skill_name] Falta delimitador de cierre '---' en YAML frontmatter"
    file_errors=$((file_errors + 1))
  fi

  name_decl="$(awk '{ sub(/\r$/, "") } NR == 1 { next } /^---[ \t]*$/ { exit } /^name:[ \t]*/ { sub(/^name:[ \t]*/, ""); print; exit }' "$skill_file")"
  if [ "$name_decl" != "$skill_name" ]; then
    red "  ❌ [$skill_name] Nombre en frontmatter ('$name_decl') no coincide con el directorio ('$skill_name')"
    file_errors=$((file_errors + 1))
  fi

  desc="$(awk '{ sub(/\r$/, "") } NR == 1 { next } /^---[ \t]*$/ { exit } /^description:[ \t]*/ { sub(/^description:[ \t]*/, ""); print; exit }' "$skill_file")"
  if [ ${#desc} -lt 25 ]; then
    red "  ❌ [$skill_name] Descripción en frontmatter demasiado corta o inexistente"
    file_errors=$((file_errors + 1))
  elif ! printf '%s\n' "$desc" | grep -qE '(^|[[:space:].,;:])Usar([[:space:].,;:]|$)'; then
    red "  ❌ [$skill_name] La descripción en frontmatter debe indicar cuándo activarse ('Usar ...')"
    file_errors=$((file_errors + 1))
  fi

  # 2. Encabezado principal H1
  if ! grep -qE "^# [^#]" "$skill_file"; then
    red "  ❌ [$skill_name] Falta título principal H1 ('# Titulo')"
    file_errors=$((file_errors + 1))
  fi

  # 3. Estructura de secciones según tipo de skill
  case "$skill_name" in
    stack-*)
      if ! grep -qE "^## [^#]" "$skill_file"; then
        red "  ❌ [$skill_name] Skill de stack sin secciones '## '"
        file_errors=$((file_errors + 1))
      fi
      ;;
    estado|iniciar-proyecto)
      if ! grep -qE "## (Protocolo|Pasos)" "$skill_file"; then
        red "  ❌ [$skill_name] Skill de flujo sin sección '## Protocolo' o '## Pasos'"
        file_errors=$((file_errors + 1))
      fi
      ;;
    *)
      role_label="Skill"
      [[ "$skill_name" == *-agent ]] && role_label="Rol especialista"
      if ! grep -qE "## (Protocolo|Pasos)" "$skill_file"; then
        red "  ❌ [$skill_name] $role_label sin sección '## Protocolo' o '## Pasos'"
        file_errors=$((file_errors + 1))
      fi
      if ! grep -qE "## .*Checklist" "$skill_file" && ! grep -q "\[ \]" "$skill_file"; then
        red "  ❌ [$skill_name] $role_label sin checklist verificable ('[ ]')"
        file_errors=$((file_errors + 1))
      fi
      if ! grep -qE "## (Prohibido|Reglas No Negociables)" "$skill_file"; then
        red "  ❌ [$skill_name] $role_label sin sección '## Prohibido' o '## Reglas No Negociables'"
        file_errors=$((file_errors + 1))
      fi
      ;;
  esac

  # 4. Verificación de enlaces relativos (raíz, plantillas y referencias)
  links="$(awk '
    /^```/ { in_code = !in_code; next }
    !in_code { print }
  ' "$skill_file" | sed 's/`[^`]*`//g' | grep -oE '\]\([^)]+\)' 2>/dev/null || true)"
  if [ -n "$links" ]; then
    links="$(printf '%s\n' "$links" | sed 's/^](\(.*\))$/\1/')"
  fi
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    case "$link" in
      http://*|https://*|mailto:*|\#*) continue ;;
    esac
    # Limpia posibles anclas (#seccion)
    clean_target="${link%%#*}"
    [ -z "$clean_target" ] && continue
    if [ "${clean_target#/}" != "$clean_target" ]; then
      target_path="$ROOT$clean_target"
    else
      target_path="$skill_dir/$clean_target"
    fi
    if [ ! -e "$target_path" ]; then
      red "  ❌ [$skill_name] Enlace roto: '$link' -> '$target_path' no existe"
      file_errors=$((file_errors + 1))
    fi
  done <<< "$links"

  if [ $file_errors -eq 0 ]; then
    green "  ✅ [$skill_name] Válida"
  else
    ERRORS=$((ERRORS + file_errors))
  fi
done

echo ""
echo "================================================================="
if [ $ERRORS -eq 0 ]; then
  green "✅ Auditoría completada: $TOTAL skills auditadas sin errores."
else
  red "❌ Auditoría finalizada con $ERRORS errores estructurales."
fi
echo "================================================================="

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0

