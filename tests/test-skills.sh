#!/usr/bin/env bash
# ==============================================================================
# Linter de Calidad y Estructura de Skills (SKILL MAESTRO)
# Uso: bash tests/test-skills.sh
# Audita metadatos YAML, integridad de enlaces relativos y secciones estándar.
# ==============================================================================

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
  if ! head -n 1 "$skill_file" | grep -q "^---"; then
    red "  ❌ [$skill_name] Falta delimitador inicial '---' en YAML frontmatter"
    file_errors=$((file_errors + 1))
  fi

  name_decl="$(grep -E "^name:[[:space:]]*" "$skill_file" | head -n 1 | sed 's/name:[[:space:]]*//' | tr -d '\r')"
  if [ "$name_decl" != "$skill_name" ]; then
    red "  ❌ [$skill_name] Nombre en frontmatter ('$name_decl') no coincide con el directorio ('$skill_name')"
    file_errors=$((file_errors + 1))
  fi

  desc="$(grep -E "^description:[[:space:]]*" "$skill_file" | head -n 1 | sed 's/description:[[:space:]]*//' | tr -d '\r')"
  if [ ${#desc} -lt 25 ]; then
    red "  ❌ [$skill_name] Descripción en frontmatter demasiado corta o inexistente"
    file_errors=$((file_errors + 1))
  fi

  # 2. Encabezado principal H1
  if ! grep -qE "^# [^#]" "$skill_file"; then
    red "  ❌ [$skill_name] Falta título principal H1 ('# Titulo')"
    file_errors=$((file_errors + 1))
  fi

  # 3. Roles especialistas (-agent): deben tener Protocolo/Pasos, Checklist y Prohibido
  if [[ "$skill_name" == *-agent ]]; then
    if ! grep -qE "## (Protocolo|Pasos)" "$skill_file"; then
      red "  ❌ [$skill_name] Rol especialista sin sección '## Protocolo' o '## Pasos'"
      file_errors=$((file_errors + 1))
    fi
    if ! grep -qE "## .*Checklist" "$skill_file" && ! grep -q "\[ \]" "$skill_file"; then
      red "  ❌ [$skill_name] Rol especialista sin checklist verificable ('[ ]')"
      file_errors=$((file_errors + 1))
    fi
    if ! grep -qE "## (Prohibido|Reglas No Negociables)" "$skill_file"; then
      red "  ❌ [$skill_name] Rol especialista sin sección '## Prohibido' o '## Reglas No Negociables'"
      file_errors=$((file_errors + 1))
    fi
  fi

  # 4. Verificación de enlaces relativos a plantillas o referencias
  # Extrae enlaces del tipo: ](references/...) o ](../../templates/...)
  links="$(grep -oE '\]\(((\.\./|references/)[^)]+)\)' "$skill_file" | sed 's/^](\(.*\))$/\1/' || true)"
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    # Limpia posibles anclas (#seccion)
    clean_target="${link%%#*}"
    target_path="$skill_dir/$clean_target"
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

exit $ERRORS
