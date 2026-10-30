---
name: bugfix
description: Corrige un bug con método - lo registra como tarea, lo reproduce, escribe primero un test que falle, encuentra la causa raíz, aplica la corrección mínima, verifica que no hay regresiones y lo entrega a QA. Usar cuando el usuario reporta un error, un comportamiento inesperado, un test roto o un fallo en producción ("no funciona", "da error", "se rompe"). No usar para funcionalidades nuevas (/nueva-tarea).
---

# /bugfix — Corrección Quirúrgica de Errores

## Pasos

1. **Revisar memoria**: busca el síntoma en `BRAIN.md` (lecciones aprendidas y *gotchas* del stack). Si existe un antídoto previo, aplícalo directamente y cita el ID `LL-XXX`.
2. **Registrar la tarea** (si no existe): identifica el especialista según la capa afectada (matriz de `orchestrator-agent`) y ejecuta:
   ```bash
   ./.agents/scripts/task.sh add "Bug: <síntoma concreto>" "<agente>" "Test de regresión en verde; <comportamiento esperado>"
   ./.agents/scripts/task.sh start TASK-XXX   # el prefijo 'Bug:' crea la rama fix/TASK-XXX-...
   ```
   *Si es un incidente de producción con impacto de servicio, avisa de inmediato al usuario y propone primero mitigar (rollback o feature flag).*
3. **Reproducir el fallo**: identifica los pasos exactos, payload de entrada, salida observada y salida esperada. Si no es reproducible, solicita los datos faltantes antes de editar código.
4. **Test de regresión (rojo primero)**: escribe la prueba automatizada mínima que exponga el fallo (unitaria, de integración o E2E) y **confirma que falla** exactamente por la causa esperada.
5. **Aislamiento de la causa raíz**: rastrea desde el síntoma hasta el origen (logs, inspección de commits con `git log -p` o `git bisect`). Describe la causa raíz técnica en una frase; si solo describe el síntoma externo, continúa investigando.
6. **Corrección mínima**: modifica estrictamente el código necesario para erradicar la causa raíz. Prohibidas las refactorizaciones oportunistas; si detectas deuda técnica adicional, regístrala con `./.agents/scripts/task.sh debt`.
7. **Verificación de regresiones**:
   - El test de regresión nuevo pasa a verde.
   - La suite completa de pruebas del proyecto (`npm test` o similar) se mantiene en verde.
   - Rastrea con `grep` si el mismo antipatrón se repite en otros módulos del proyecto y corrígelo.
   - Ejecuta `./.agents/scripts/scan-secrets.sh --branch` para asegurar que no se introdujeron credenciales durante la depuración.
8. **Commit y entrega**: realiza el commit con `./.agents/scripts/task.sh commit TASK-XXX "<descripción del arreglo>" fix` y ejecuta `/handoff`.
9. **Cierre de aprendizaje**: tras la aprobación en QA, si el defecto fue complejo, de concurrencia, seguridad o incompatibilidad de librerías, ejecuta `/aprender` para incorporar el antídoto en `BRAIN.md`.

## Checklist antes de `task.sh handoff`
- [ ] Test automatizado de regresión añadido y pasando en verde.
- [ ] Causa raíz técnica identificada y documentada en el mensaje de entrega.
- [ ] Suite completa de pruebas ejecutada sin fallos ni regresiones secundarias.
- [ ] Sin cambios de estilo o refactorizaciones fuera del alcance del bug.
- [ ] Escaneo de secretos limpio (`./.agents/scripts/scan-secrets.sh --branch`).

## Prohibido
- Silenciar el error mediante bloques `try/catch` vacíos, encadenamiento opcional `?.` defensivo sin causa, o modificando la aserción del test para que pase.
- Marcar o entregar un bug sin una prueba automatizada de regresión que lo reproduzca.
- Introducir refactorizaciones cosméticas o no relacionadas en el diff de la corrección.
