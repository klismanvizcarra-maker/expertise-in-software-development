---
name: onboarding
description: Genera y actualiza la guía completa de inducción técnica para desarrolladores humanos (docs/onboarding/guide.md) - inspecciona el stack, comandos de setup local, variables de entorno, arquitectura C4 y dinámica de trabajo con agentes para facilitar la integración rápida de nuevas personas al equipo. Usar cuando un nuevo desarrollador se sume al proyecto, al preparar la documentación de bienvenida de un equipo o para auditar que el setup local siga funcionando. No usar para adoptar un proyecto brownfield en el sistema multi-agente (usar adoptar-proyecto) ni para iniciar un repositorio desde cero (usar iniciar-proyecto).
---

# /onboarding — Guía de Inducción para Desarrolladores Humanos

La skill de flujo `/onboarding` garantiza que cualquier ingeniero humano que se incorpore al repositorio pueda levantar el entorno local, comprender la arquitectura y colaborar con los agentes de IA en menos de 15 minutos.

---

## Pasos

1. **Inspección del Proyecto**:
   - Lee `GLOBAL_STATE.md` para identificar el stack tecnológico, dependencias y reglas de gobernanza.
   - Revisa `.env.example`, `package.json` (o equivalente en Python) y `docker-compose.yml` si existe.
   - Identifica las rutas principales del código según la skill de stack activa.

2. **Generación o Actualización de la Guía**:
   - Crea o actualiza `docs/onboarding/guide.md` partiendo de la plantilla `.agents/templates/onboarding_guide_template.md`.
   - Documenta los 3 comandos exactos de inicio rápido.
   - Modela el diagrama de arquitectura en Mermaid adaptado a la estructura real del proyecto.
   - Explica el flujo de trabajo de los agentes (`/nueva-tarea`, `/probar-usuario`, `/qa-review`).

3. **Verificación del Setup Local**:
   - Comprueba que los comandos documentados no fallen y que las variables de `.env.example` estén comentadas.
   - Verifica que el script `./.agents/scripts/install-hooks.sh` quede documentado para proteger commits.

4. **Entrega y Puntos de Contacto**:
   - Presenta al desarrollador el enlace a `docs/onboarding/guide.md` y un resumen ejecutivo de las convenciones de `AGENTS.md`.

---

## Checklist

- [ ] Archivo `docs/onboarding/guide.md` generado y actualizado con datos reales del proyecto.
- [ ] Comandos de setup local (git, dependencias, variables, ejecución) verificados y funcionales.
- [ ] Diagrama de arquitectura Mermaid renderizable y coherente con el código.
- [ ] Protocolo de tareas (`task.sh`, `/nueva-tarea`) claramente explicado para humanos.
- [ ] Enlace al documento `BRAIN.md` para que el desarrollador conozca las lecciones del proyecto.

---

## Prohibido

- Prohibido generar guías de onboarding con variables o comandos ficticios no comprobados.
- Prohibido omitir la advertencia de que ningún código se edita sin una tarea activa (`AGENTS.md` §2.4).
- Prohibido sobreescribir configuraciones locales del usuario sin previo aviso.
