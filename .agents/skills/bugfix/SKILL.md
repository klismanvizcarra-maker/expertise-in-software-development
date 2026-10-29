---
name: bugfix
description: Corrige un bug con método - lo registra como tarea, lo reproduce, escribe primero un test que falle, encuentra la causa raíz, aplica la corrección mínima, verifica que no hay regresiones y lo entrega a QA. Usar cuando el usuario reporta un error, un comportamiento inesperado, un test roto o un fallo en producción ("no funciona", "da error", "se rompe"). No usar para funcionalidades nuevas (/nueva-tarea).
---

# /bugfix — Corrección de Errores

## Pasos

1. **Revisar memoria**: busca el síntoma en `BRAIN.md` (lecciones y *gotchas*). Si ya hay un antídoto, aplícalo y menciónalo.
2. **Registrar la tarea** (si no existe): elige el agente según la capa del fallo (tabla de enrutamiento de `orchestrator-agent`) y ejecuta
   ```bash
   ./.agents/scripts/task.sh add "Bug: <síntoma>" "<agente>" "Test de regresión en verde; <comportamiento esperado>"
   ./.agents/scripts/task.sh start TASK-XXX   # el prefijo "Bug:" crea la rama fix/TASK-XXX-...
   ```
   Si es un fallo en producción con impacto, dilo al usuario antes de nada y propone primero mitigar (rollback o desactivar la funcionalidad).
3. **Reproducir**: consigue pasos exactos, entrada, salida observada y esperada. Si no puedes reproducirlo, pide los datos que faltan; no corrijas a ciegas.
4. **Test que falla primero**: escribe la prueba de regresión más pequeña que demuestre el bug (unitaria si es lógica, de integración si es un endpoint, E2E si es un flujo de UI) y **comprueba que falla** por el motivo correcto.
5. **Causa raíz**: rastrea desde el síntoma hasta el origen (logs, `git log -p` / `git bisect` sobre los archivos implicados). Escribe la causa en una frase; si solo describe el síntoma, sigue buscando.
6. **Corrección mínima**: cambia solo lo necesario para eliminar la causa. Nada de refactors oportunistas; si ves deuda, regístrala con `task.sh debt`.
7. **Verificar**: el test nuevo pasa, la suite completa sigue en verde y el escenario original ya no se reproduce. Busca el mismo patrón en otros puntos del código (`grep`) y corrígelos o regístralos.
8. **Entregar**: commit con `./.agents/scripts/task.sh commit TASK-XXX "<descripción>" fix` y luego `/handoff`, incluyendo en el resumen: causa raíz, corrección y test de regresión añadido.
9. **Aprender**: tras la aprobación de QA, si el bug no era trivial, ejecuta `/aprender` con problema, causa y solución.

## Prohibido
- Silenciar el error (try/catch vacío, `?.` defensivo, desactivar el test) en lugar de corregir la causa.
- Cerrar el bug sin test de regresión.
