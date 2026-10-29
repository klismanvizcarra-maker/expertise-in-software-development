# Punto de Entrada para Claude Code

> Claude Code lee `CLAUDE.md`, no `AGENTS.md`. Este archivo solo importa las reglas compartidas para que Claude y Antigravity obedezcan exactamente la misma fuente.

@AGENTS.md

---

## Notas Específicas de Claude Code

- **Skills**: `.claude/skills` es un enlace simbólico a `.agents/skills/`. Edita siempre las skills en `.agents/skills/` (fuente única compartida con Antigravity).
- **MCP**: los servidores del proyecto se declaran en `.mcp.json` (raíz). Antigravity usa la copia en `.agents/plugins/maestro-mcp/mcp_config.json`; ambas se generan desde `.agents/templates/mcp_config_template.json`.
- **Invocación**: cualquier skill puede activarse explícitamente con `/<nombre-de-la-skill>` (ej. `/orchestrator-agent`).
