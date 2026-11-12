#!/usr/bin/env bash
# ==============================================================================
# Script de Inicialización de Nuevos Proyectos Multi-Agente
# Instala el sistema para Antigravity (.agents/ + AGENTS.md) y Claude Code
# (.claude/skills + CLAUDE.md + .mcp.json) desde una única fuente.
# ==============================================================================
# Uso:
#   ./init-project.sh "Mi Proyecto" "/ruta/al/nuevo/proyecto" [--copy] [--stack nextjs|angular|fastapi] [--ci]
#   ./init-project.sh --adopt ["/ruta/al/proyecto-existente"] [--stack ...] [--ci] [--copy]
#   O simplemente: ./init-project.sh "Mi Proyecto"
#
#   --copy               Copia las skills en .claude/skills en vez de crear un enlace
#                        simbólico (útil en Windows o si el repositorio no admite symlinks).
#   --stack <nombre>     Pre-configura el stack tecnológico en GLOBAL_STATE.md sin
#                        placeholders (opciones: nextjs | angular | fastapi).
#   --ci                 Instala el pipeline de GitHub Actions (.github/workflows/audit.yml)
#                        a partir de ci_workflow_template.yml sin sobrescribir si ya existe.
#   --adopt              Adopta un repositorio existente (brownfield): instala .agents/,
#                        reglas y hooks sin sobrescribir código, docs, .gitignore,
#                        .env.example, README.md, GLOBAL_STATE.md, BRAIN.md ni hooks previos.
#   --update, -u         Sincroniza scripts, plantillas, hooks y skills existentes sin tocar
#                        GLOBAL_STATE.md, BRAIN.md ni .agents/brain/.
# ==============================================================================

set -euo pipefail

PROJECT_NAME="Nuevo Proyecto"
TARGET_DIR="."
LINK_MODE="symlink"
SELECTED_STACK=""
IS_UPDATE=0
IS_ADOPT=0
INSTALL_CI=0

positional=()
while [ $# -gt 0 ]; do
  case "$1" in
    --copy)
      LINK_MODE="copy"
      shift
      ;;
    --update|-u)
      IS_UPDATE=1
      shift
      ;;
    --adopt)
      IS_ADOPT=1
      shift
      ;;
    --ci)
      INSTALL_CI=1
      shift
      ;;
    --stack)
      if [ -z "${2:-}" ] || [ "${2#-}" != "$2" ]; then
        echo "❌ ERROR: --stack requiere un valor (nextjs, angular o fastapi)." >&2
        exit 1
      fi
      SELECTED_STACK="$2"
      shift 2
      ;;
    --stack=*)
      SELECTED_STACK="${1#*=}"
      if [ -z "$SELECTED_STACK" ]; then
        echo "❌ ERROR: --stack= requiere un valor (nextjs, angular o fastapi)." >&2
        exit 1
      fi
      shift
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

if [ "$IS_UPDATE" -eq 1 ] && [ "$IS_ADOPT" -eq 1 ]; then
  echo "❌ ERROR: Usa --update o --adopt, no ambos a la vez." >&2
  exit 1
fi

if [ -n "$SELECTED_STACK" ]; then
  case "$SELECTED_STACK" in
    nextjs|angular|fastapi) ;;
    *)
      echo "❌ ERROR: Stack desconocido: '$SELECTED_STACK'." >&2
      echo "   Valores permitidos: nextjs, angular, fastapi." >&2
      exit 1
      ;;
  esac
fi

if [ "$IS_UPDATE" -eq 1 ]; then
  if [ -n "${positional[0]:-}" ]; then
    TARGET_DIR="${positional[0]}"
  fi
elif [ "$IS_ADOPT" -eq 1 ]; then
  if [ "${#positional[@]}" -ge 2 ]; then
    PROJECT_NAME="${positional[0]}"
    TARGET_DIR="${positional[1]}"
  elif [ "${#positional[@]}" -eq 1 ]; then
    ARG0="${positional[0]}"
    if [ -d "$ARG0" ] || [ "$ARG0" = "." ] || [ "$ARG0" = ".." ] || [ "${ARG0#*/}" != "$ARG0" ]; then
      TARGET_DIR="$ARG0"
      [ -d "$TARGET_DIR" ] && PROJECT_NAME=$(basename "$(cd "$TARGET_DIR" && pwd)")
    else
      PROJECT_NAME="$ARG0"
      TARGET_DIR="."
    fi
  else
    TARGET_DIR="."
    PROJECT_NAME=$(basename "$(pwd)")
  fi
  [ -d "$TARGET_DIR" ] || {
    echo "❌ ERROR: El directorio de destino '$TARGET_DIR' no existe (--adopt requiere un proyecto existente)." >&2
    exit 1
  }
else
  [ -n "${positional[0]:-}" ] && PROJECT_NAME="${positional[0]}"
  [ -n "${positional[1]:-}" ] && TARGET_DIR="${positional[1]}"
fi
CURRENT_DATE=$(date +"%Y-%m-%d")

# Directorio donde se encuentra este script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Copia un archivo solo si no existe en el destino (nunca sobrescribe trabajo previo)
copy_if_missing() {
  if [ -e "$2" ]; then
    echo "   (se conserva $2 existente)"
  else
    cp "$1" "$2"
  fi
}

if [ "$IS_UPDATE" -eq 1 ]; then
  [ -d "$TARGET_DIR" ] || {
    echo "❌ ERROR: El directorio de destino '$TARGET_DIR' no existe." >&2
    exit 1
  }
  echo "================================================================="
  echo "  Actualizando Entorno Multi-Agente en: $TARGET_DIR"
  echo "================================================================="

  mkdir -p "$TARGET_DIR/.agents/skills"
  mkdir -p "$TARGET_DIR/.agents/templates"
  mkdir -p "$TARGET_DIR/.agents/scripts"
  mkdir -p "$TARGET_DIR/.agents/hooks"
  mkdir -p "$TARGET_DIR/.agents/plugins"
  mkdir -p "$TARGET_DIR/.agents/reviews"

  echo "-> Sincronizando catálogo de skills..."
  cp -R "$SKILL_ROOT/.agents/skills/"* "$TARGET_DIR/.agents/skills/"

  # Eliminar skills retiradas
  for sdir in "$TARGET_DIR/.agents/skills/"*; do
    if [ -d "$sdir" ]; then
      sname=$(basename "$sdir")
      if [ ! -d "$SKILL_ROOT/.agents/skills/$sname" ]; then
        echo "   (eliminando skill retirada: $sname)"
        rm -rf "$sdir"
      fi
    fi
  done

  echo "-> Sincronizando scripts, plantillas, hooks y plugins..."
  cp -R "$SKILL_ROOT/.agents/scripts/"* "$TARGET_DIR/.agents/scripts/"
  chmod +x "$TARGET_DIR/.agents/scripts/"*.sh 2>/dev/null || true
  cp -R "$SKILL_ROOT/.agents/templates/"* "$TARGET_DIR/.agents/templates/"
  cp -R "$SKILL_ROOT/.agents/hooks/"* "$TARGET_DIR/.agents/hooks/"
  chmod +x "$TARGET_DIR/.agents/hooks/"* 2>/dev/null || true
  cp -R "$SKILL_ROOT/.agents/plugins/"* "$TARGET_DIR/.agents/plugins/"

  if [ -f "$SKILL_ROOT/.agents/VERSION" ]; then
    cp "$SKILL_ROOT/.agents/VERSION" "$TARGET_DIR/.agents/VERSION"
  fi

  if [ -d "$TARGET_DIR/.claude" ]; then
    if [ -d "$TARGET_DIR/.claude/skills" ] && [ ! -L "$TARGET_DIR/.claude/skills" ]; then
      cp -R "$TARGET_DIR/.agents/skills/"* "$TARGET_DIR/.claude/skills/"
      for sdir in "$TARGET_DIR/.claude/skills/"*; do
        if [ -d "$sdir" ]; then
          sname=$(basename "$sdir")
          if [ ! -d "$SKILL_ROOT/.agents/skills/$sname" ]; then
            rm -rf "$sdir"
          fi
        fi
      done
    fi
  fi

  # .claude/settings.json y AGENTS.md son del proyecto y no se sobrescriben: solo se avisa de novedades
  if [ -f "$TARGET_DIR/.claude/settings.json" ] && ! grep -q 'brain-context.sh' "$TARGET_DIR/.claude/settings.json"; then
    echo "   (aviso: .claude/settings.json no registra el hook del cerebro; añade la entrada"
    echo "    'brain-context.sh' de .agents/templates/claude_settings_template.json para que"
    echo "    las lecciones se muestren al editar los archivos de su ámbito)"
  fi
  if [ -f "$SKILL_ROOT/AGENTS.md" ] && [ -f "$TARGET_DIR/AGENTS.md" ] && ! cmp -s "$SKILL_ROOT/AGENTS.md" "$TARGET_DIR/AGENTS.md"; then
    echo "   (aviso: AGENTS.md del proyecto difiere del de la librería; revísalo si incorporas nuevas reglas de gobierno)"
  fi

  if [ -d "$TARGET_DIR/.git" ]; then
    echo "-> Actualizando Git Hooks en repositorio..."
    (cd "$TARGET_DIR" && bash ./.agents/scripts/install-hooks.sh) || true
  fi

  if [ "$INSTALL_CI" -eq 1 ]; then
    echo "-> Configurando pipeline CI (.github/workflows/audit.yml)..."
    mkdir -p "$TARGET_DIR/.github/workflows"
    copy_if_missing "$SKILL_ROOT/.agents/templates/ci_workflow_template.yml" "$TARGET_DIR/.github/workflows/audit.yml"
  fi

  echo "================================================================="
  echo "  [OK] Actualización completada exitosamente!"
  echo "       GLOBAL_STATE.md, BRAIN.md y .agents/brain/ se conservaron intactos."
  echo "================================================================="
  exit 0
fi

echo "================================================================="
if [ "$IS_ADOPT" -eq 1 ]; then
  echo "  Adoptando Proyecto Existente (Brownfield): $PROJECT_NAME"
else
  echo "  Inicializando Entorno Multi-Agente para: $PROJECT_NAME"
fi
echo "  Directorio de destino: $TARGET_DIR"
[ -n "$SELECTED_STACK" ] && echo "  Stack tecnológico: $SELECTED_STACK"
echo "================================================================="

# Crear carpetas en el destino si no existen
mkdir -p "$TARGET_DIR/.agents/skills"
mkdir -p "$TARGET_DIR/.agents/templates"
mkdir -p "$TARGET_DIR/.agents/scripts"
mkdir -p "$TARGET_DIR/.agents/brain"
mkdir -p "$TARGET_DIR/.agents/hooks"
mkdir -p "$TARGET_DIR/.agents/plugins"
mkdir -p "$TARGET_DIR/.agents/reviews"
if [ "$IS_ADOPT" -eq 0 ]; then
  mkdir -p "$TARGET_DIR/docs/product"
fi

# Copiar skills, templates, brain, scripts, hooks y plugins
echo "-> Copiando catalogo de skills, plantillas y modulos de memoria..."
cp -R "$SKILL_ROOT/.agents/skills/"* "$TARGET_DIR/.agents/skills/"
cp -R "$SKILL_ROOT/.agents/templates/"* "$TARGET_DIR/.agents/templates/"
cp -R "$SKILL_ROOT/.agents/scripts/"* "$TARGET_DIR/.agents/scripts/"
cp -R "$SKILL_ROOT/.agents/hooks/"* "$TARGET_DIR/.agents/hooks/"
cp -R "$SKILL_ROOT/.agents/plugins/"* "$TARGET_DIR/.agents/plugins/"
if [ -f "$SKILL_ROOT/.agents/VERSION" ]; then
  cp "$SKILL_ROOT/.agents/VERSION" "$TARGET_DIR/.agents/VERSION"
fi

# Dar permisos de ejecución
chmod +x "$TARGET_DIR/.agents/scripts/"*.sh 2>/dev/null || true
chmod +x "$TARGET_DIR/.agents/hooks/"* 2>/dev/null || true

# Reglas globales: AGENTS.md (Antigravity) + CLAUDE.md que lo importa (Claude Code)
echo "-> Instalando reglas maestras AGENTS.md y CLAUDE.md..."
copy_if_missing "$SKILL_ROOT/AGENTS.md" "$TARGET_DIR/AGENTS.md"
if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
  if ! grep -q '^@AGENTS.md' "$TARGET_DIR/CLAUDE.md"; then
    printf '\n@AGENTS.md\n' >> "$TARGET_DIR/CLAUDE.md"
    echo "   (se añadió @AGENTS.md al CLAUDE.md existente)"
  fi
else
  cp "$SKILL_ROOT/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
fi

# Skills para Claude Code: enlace a la fuente única .agents/skills
echo "-> Conectando skills con Claude Code (.claude/skills, modo: $LINK_MODE)..."
mkdir -p "$TARGET_DIR/.claude"
if [ -L "$TARGET_DIR/.claude/skills" ] || [ ! -e "$TARGET_DIR/.claude/skills" ]; then
  rm -f "$TARGET_DIR/.claude/skills"
  if [ "$LINK_MODE" = "symlink" ]; then
    ln -s ../.agents/skills "$TARGET_DIR/.claude/skills"
  else
    cp -R "$TARGET_DIR/.agents/skills" "$TARGET_DIR/.claude/skills"
  fi
else
  # Ya existe una carpeta real con skills propias: añadir las del sistema sin borrar nada
  cp -R "$TARGET_DIR/.agents/skills/"* "$TARGET_DIR/.claude/skills/"
fi

# Servidores MCP: .mcp.json (Claude Code). Antigravity los toma del plugin maestro-mcp.
echo "-> Instalando configuracion MCP (.mcp.json)..."
copy_if_missing "$SKILL_ROOT/.agents/templates/mcp_config_template.json" "$TARGET_DIR/.mcp.json"

# Hook de Claude Code que exige una tarea IN_PROGRESS antes de editar código (AGENTS.md §2.4)
echo "-> Instalando hooks de Claude Code: 'Cero Código sin Tarea' y cerebro (.claude/settings.json)..."
if [ -e "$TARGET_DIR/.claude/settings.json" ]; then
  echo "   (se conserva .claude/settings.json existente: añade a mano los hooks de"
  echo "    .agents/templates/claude_settings_template.json)"
else
  cp "$SKILL_ROOT/.agents/templates/claude_settings_template.json" "$TARGET_DIR/.claude/settings.json"
fi

# Copiar .gitignore y .env.example
echo "-> Instalando .gitignore y .env.example..."
copy_if_missing "$SKILL_ROOT/.gitignore" "$TARGET_DIR/.gitignore"
copy_if_missing "$SKILL_ROOT/.agents/templates/env_template.example" "$TARGET_DIR/.env.example"

# Crear GLOBAL_STATE.md a partir de la plantilla
if [ -f "$TARGET_DIR/GLOBAL_STATE.md" ]; then
  echo "-> GLOBAL_STATE.md ya existe; se conserva."
else
  echo "-> Generando GLOBAL_STATE.md configurado..."
  python3 -c "
import sys
pname, date, src, dst = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(src, 'r', encoding='utf-8') as f:
    c = f.read()
c = c.replace('[NOMBRE_DEL_PROYECTO]', pname).replace('YYYY-MM-DD', date)
with open(dst, 'w', encoding='utf-8') as f:
    f.write(c)
" "$PROJECT_NAME" "$CURRENT_DATE" "$SKILL_ROOT/.agents/templates/GLOBAL_STATE_TEMPLATE.md" "$TARGET_DIR/GLOBAL_STATE.md"

  if [ "$IS_ADOPT" -eq 1 ]; then
    tmp_gs=$(mktemp)
    STACK_SET="$SELECTED_STACK" awk '
      /^\|[ \t]*`?TASK-00[12]`?[ \t]*\|/ { next }
      /^\- \*\*Fase Actual\*\*:/ { print "- **Fase Actual**: `FASE 0: Adopción e Inventario (Brownfield)`"; next }
      ENVIRON["STACK_SET"] == "" && /^\|.*\|[ \t]*Elección del stack base[ \t]*\|/ { next }
      { print }
    ' "$TARGET_DIR/GLOBAL_STATE.md" > "$tmp_gs"
    cat "$tmp_gs" > "$TARGET_DIR/GLOBAL_STATE.md" && rm -f "$tmp_gs"
  fi

  # Configurar stack tecnológico predeterminado si se especificó
  if [ "$SELECTED_STACK" = "nextjs" ]; then
    sed -i.bak \
      -e "s|- \*\*Frontend\*\*:.*|- **Frontend**: \`React 19 + Next.js 15 (App Router, Server Components y Tailwind CSS)\`|g" \
      -e "s|- \*\*Backend\*\*:.*|- **Backend**: \`Next.js Server Actions y Route Handlers con validación Zod\`|g" \
      -e "s|- \*\*Persistencia\*\*:.*|- **Persistencia**: \`PostgreSQL con Prisma ORM (migraciones versionadas)\`|g" \
      -e "s|- \*\*Autenticación\*\*:.*|- **Autenticación**: \`Sesiones seguras con cookies HttpOnly / Auth.js\`|g" \
      -e "s|- \*\*Infraestructura & Despliegue\*\*:.*|- **Infraestructura \& Despliegue**: \`Docker multi-etapa / Vercel / Render\`|g" \
      -e "s|Elección del stack base|Elección del stack React 19 + Next.js 15 + Prisma (stack-nextjs-tailwind-prisma)|g" \
      -e "s|\[Breve descripción[^]]*\]|Aplicación web construida con React 19, Next.js 15 App Router, Tailwind CSS y Prisma ORM.|g" \
      "$TARGET_DIR/GLOBAL_STATE.md"
    rm -f "$TARGET_DIR/GLOBAL_STATE.md.bak"
    echo "   (Stack Next.js configurado en GLOBAL_STATE.md)"
  elif [ "$SELECTED_STACK" = "angular" ]; then
    sed -i.bak \
      -e "s|- \*\*Frontend\*\*:.*|- **Frontend**: \`Angular 22 (Standalone, Zoneless, OnPush, Signals)\`|g" \
      -e "s|- \*\*Backend\*\*:.*|- **Backend**: \`Node 24 LTS con Express 5 y validación Zod\`|g" \
      -e "s|- \*\*Persistencia\*\*:.*|- **Persistencia**: \`PostgreSQL 18 con Drizzle ORM\`|g" \
      -e "s|- \*\*Autenticación\*\*:.*|- **Autenticación**: \`Tokens JWT propios con rotación de refresh\`|g" \
      -e "s|- \*\*Infraestructura & Despliegue\*\*:.*|- **Infraestructura \& Despliegue**: \`Docker multi-etapa / Nginx SSR / VPS\`|g" \
      -e "s|Elección del stack base|Elección del stack Angular 22 + Express 5 + PostgreSQL (stack-angular-express-postgres)|g" \
      -e "s|\[Breve descripción[^]]*\]|Aplicación web en monorepo npm con Angular 22, Express 5 y PostgreSQL 18 con Drizzle.|g" \
      "$TARGET_DIR/GLOBAL_STATE.md"
    rm -f "$TARGET_DIR/GLOBAL_STATE.md.bak"
    echo "   (Stack Angular configurado en GLOBAL_STATE.md)"
  elif [ "$SELECTED_STACK" = "fastapi" ]; then
    sed -i.bak \
      -e "s|- \*\*Frontend\*\*:.*|- **Frontend**: \`Independiente (consume el contrato OpenAPI de la API)\`|g" \
      -e "s|- \*\*Backend\*\*:.*|- **Backend**: \`Python 3.12 con FastAPI y validación Pydantic v2\`|g" \
      -e "s|- \*\*Persistencia\*\*:.*|- **Persistencia**: \`PostgreSQL con SQLAlchemy 2 (async) y migraciones Alembic\`|g" \
      -e "s|- \*\*Autenticación\*\*:.*|- **Autenticación**: \`Tokens JWT con hash de contraseñas argon2/bcrypt\`|g" \
      -e "s|- \*\*Infraestructura & Despliegue\*\*:.*|- **Infraestructura \& Despliegue**: \`Docker multi-etapa / uvicorn / VPS\`|g" \
      -e "s|Elección del stack base|Elección del stack FastAPI + SQLAlchemy + PostgreSQL (stack-fastapi-postgres)|g" \
      -e "s|\[Breve descripción[^]]*\]|API en Python con FastAPI, SQLAlchemy 2, Alembic y PostgreSQL.|g" \
      "$TARGET_DIR/GLOBAL_STATE.md"
    rm -f "$TARGET_DIR/GLOBAL_STATE.md.bak"
    echo "   (Stack FastAPI configurado en GLOBAL_STATE.md)"
  fi
fi

# Crear BRAIN.md y los módulos de memoria sin sobrescribir lo que el proyecto ya aprendió.
# En archivos nuevos se eliminan las filas de ejemplo (LL-/TD-) para empezar con IDs limpios.
echo "-> Inicializando BRAIN.md y .agents/brain/ (Memoria a Largo Plazo)..."
strip_examples() {
  local tmp
  tmp=$(mktemp)
  grep -vE '^\|[ \t]*`?(LL|TD)-[0-9]+' "$1" > "$tmp" || true
  cat "$tmp" > "$1" && rm -f "$tmp"
}
install_brain_file() {
  if [ -e "$2" ]; then
    echo "   (se conserva $2 existente)"
  else
    cp "$1" "$2"
    strip_examples "$2"
  fi
}
install_brain_file "$SKILL_ROOT/.agents/templates/BRAIN_TEMPLATE.md" "$TARGET_DIR/BRAIN.md"
install_brain_file "$SKILL_ROOT/.agents/templates/lessons_learned_template.md" "$TARGET_DIR/.agents/brain/lessons_learned.md"
install_brain_file "$SKILL_ROOT/.agents/templates/system_map_template.md" "$TARGET_DIR/.agents/brain/system_map.md"
install_brain_file "$SKILL_ROOT/.agents/templates/preferences_template.md" "$TARGET_DIR/.agents/brain/preferences.md"
install_brain_file "$SKILL_ROOT/.agents/templates/domain_glossary_template.md" "$TARGET_DIR/.agents/brain/domain_glossary.md"
install_brain_file "$SKILL_ROOT/.agents/templates/tech_debt_template.md" "$TARGET_DIR/.agents/brain/tech_debt.md"

# Generar README.md si no existe en el destino
if [ ! -f "$TARGET_DIR/README.md" ]; then
  echo "-> Generando README.md del proyecto..."
  python3 -c "
import sys
pname, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src, 'r', encoding='utf-8') as f:
    c = f.read()
c = c.replace('[NOMBRE_DEL_PROYECTO]', pname)
with open(dst, 'w', encoding='utf-8') as f:
    f.write(c)
" "$PROJECT_NAME" "$SKILL_ROOT/.agents/templates/README_TEMPLATE.md" "$TARGET_DIR/README.md"
fi

# Instalar Git hooks si existe .git
if [ -d "$TARGET_DIR/.git" ]; then
  echo "-> Instalando Git Hooks en repositorio local..."
  if [ "$IS_ADOPT" -eq 1 ]; then
    (cd "$TARGET_DIR" && bash ./.agents/scripts/install-hooks.sh --preserve-existing) || true
  else
    (cd "$TARGET_DIR" && bash ./.agents/scripts/install-hooks.sh) || true
  fi
fi

# Configurar pipeline CI si se especificó --ci
if [ "$INSTALL_CI" -eq 1 ]; then
  echo "-> Configurando pipeline CI (.github/workflows/audit.yml)..."
  mkdir -p "$TARGET_DIR/.github/workflows"
  copy_if_missing "$SKILL_ROOT/.agents/templates/ci_workflow_template.yml" "$TARGET_DIR/.github/workflows/audit.yml"
fi

echo "================================================================="
if [ "$IS_ADOPT" -eq 1 ]; then
  echo "  [OK] Adopción brownfield instalada sin sobrescribir trabajo previo!"
else
  echo "  [OK] Inicializacion completada exitosamente!"
fi
echo ""
echo "  Archivos generados:"
echo "    - $TARGET_DIR/AGENTS.md (Reglas globales; Antigravity)"
echo "    - $TARGET_DIR/CLAUDE.md (Importa AGENTS.md; Claude Code)"
echo "    - $TARGET_DIR/.claude/skills (Skills para Claude Code -> .agents/skills)"
echo "    - $TARGET_DIR/.mcp.json (Servidores MCP; Claude Code)"
echo "    - $TARGET_DIR/.claude/settings.json (Hook: cero codigo sin tarea; Claude Code)"
echo "    - $TARGET_DIR/.agents/plugins/maestro-mcp/ (Servidores MCP; Antigravity)"
echo "    - $TARGET_DIR/GLOBAL_STATE.md (Unica Fuente de Verdad SSOT)"
echo "    - $TARGET_DIR/BRAIN.md (Cerebro y Memoria Persistente)"
echo "    - $TARGET_DIR/.agents/scripts/task.sh (CLI de gestion de tareas)"
[ "$INSTALL_CI" -eq 1 ] && echo "    - $TARGET_DIR/.github/workflows/audit.yml (Pipeline CI)"
echo ""
command -v npx >/dev/null 2>&1 || {
  echo "  [AVISO] 'npx' no esta instalado: el MCP web-tester-playwright no arrancara."
  echo "          Instala Node.js LTS."
  echo ""
}
echo "  Siguiente paso:"
if [ "$IS_ADOPT" -eq 1 ]; then
  echo "    Abre el proyecto en Claude Code o Antigravity y ejecuta /adoptar-proyecto"
  echo "    para inventariar el codebase existente, ajustar rutas y registrar el estado."
else
  echo "    Abre el proyecto en Claude Code o Antigravity y dale tu primer"
  echo "    requerimiento al Orchestrator Agent (/orchestrator-agent)."
fi
echo "================================================================="
