# BUG-TASK-081-1 — El linter de presupuesto no cuenta SKILL.md con frontmatter distinto

- **Tarea**: TASK-081 · **Iteración**: 1/3 · **Severidad**: MEDIA · **Reporta**: qa-security-agent

## Descripción
`load_skills()` de `tests/triggers/lint_descriptions.py` solo reconoce el frontmatter exacto `---\nname: …\ndescription: …\n---`. Una SKILL.md con `description` antes de `name`, con claves extra o con `description: >` multilínea no se cuenta y no se avisa, pero `test-skills.sh` y Claude Code sí la aceptan: vuelve a gastar presupuesto del listado sin que nada lo detecte.

## Pasos de reproducción
1. Copiar `.agents/skills` a un temporal y añadir `zz-bypass/SKILL.md` con `---\ndescription: Usar cuando <2000 caracteres>\nname: zz-bypass\n---`.
2. `python3 tests/triggers/lint_descriptions.py --skills-dir <tmp>` → exit 0, "Skills: 56", "14777/15000".

## Esperado
El linter carga toda SKILL.md (cualquier orden de claves y descripciones multilínea) o falla nombrando la que no puede leer.

## Observaciones BAJA incluidas en el rechazo
- Límites perdidos al compactar: stack-angular-express-postgres sin "No usar" (choca con stack-react-vite-node, que también usa Express) ni "junto con la skill del rol"; devsecops-agent ↔ devops-cloud-agent; nueva-tarea ↔ orchestrator-agent; orchestrator-agent → product-manager-agent; user-testing-agent ↔ probar-usuario.
- La cifra de partida "31 840 caracteres" son bytes; en caracteres eran 31 495.
- Los checks negativos nuevos de test-scripts.sh solo miran el exit code, no el mensaje "máximo".
