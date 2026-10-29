---
name: aprender
description: Registra una lección aprendida en la memoria permanente del proyecto (BRAIN.md y .agents/brain/lessons_learned.md) con problema, causa raíz y solución, para que ningún agente repita el error. También registra deuda técnica aceptada. Usar tras resolver un bug no trivial, descubrir una incompatibilidad de librerías o un comportamiento inesperado del stack, o cuando el usuario dice "recuerda esto", "aprende" o "anota esta lección".
---

# /aprender — Memoria Permanente

## Pasos

1. **Extraer la lección** de la conversación o de lo que diga el usuario. Debe tener tres partes concretas:
   - **Problema**: el síntoma observable (`Login devolvía 500 con email vacío`).
   - **Causa raíz**: por qué ocurría, no el síntoma otra vez.
   - **Solución**: la regla preventiva aplicable a futuro (`Validar con Zod en el middleware antes del servicio`).
   Si falta alguna, pregúntala. No registres lecciones genéricas que cualquier desarrollador ya sabe.
2. **Elegir categoría**: `frontend`, `backend`, `database`, `security`, `devops`, `mobile`, `ai`, `ui/ux` o `domain`.
3. **Evitar duplicados**: busca en `BRAIN.md` una lección equivalente; si existe, actualízala en lugar de crear otra.
4. **Registrar**:
   ```bash
   ./.agents/scripts/task.sh learn "<problema>" <categoría> "<causa raíz>" "<solución>"
   ```
   Evita el carácter `|` en los textos.
5. **Si es una trampa de una librería o versión concreta**, añade además una fila en la tabla *Quirks y Trampas Conocidas* de `BRAIN.md` (tecnología, versión, comportamiento, regla de prevención).
6. **Si es una preferencia del usuario** (estilo, convenciones), regístrala en `.agents/brain/preferences.md` en lugar de como lección.
7. **Confirmar** al usuario el ID asignado (`LL-XXX`).

## Deuda Técnica
Si en lugar de una lección se trata de un atajo aceptado temporalmente:
```bash
./.agents/scripts/task.sh debt "<descripción>" TASK-XXX "<acción definitiva>" [ALTA|MEDIA|BAJA]
```
Nunca se acepta como deuda algo que comprometa seguridad, privacidad o estabilidad.
