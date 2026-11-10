---
name: aprender
description: Registra una lección aprendida en la memoria permanente del proyecto (BRAIN.md y .agents/brain/lessons_learned.md) con problema, causa raíz y solución, para que ningún agente repita el error. También registra deuda técnica aceptada. Usar tras resolver un bug no trivial, descubrir una incompatibilidad de librerías o un comportamiento inesperado del stack, o cuando el usuario dice "recuerda esto", "aprende" o "anota esta lección".
---

# /aprender — Memoria Permanente

## Pasos

1. **Extraer la lección**: obtén de la conversación o de la indicación del usuario los tres componentes esenciales:
   - **Problema observable**: el síntoma o fallo exacto (`Login devolvía 500 con cuerpo JSON vacío`).
   - **Causa raíz técnica**: el mecanismo de fallo a nivel de código o arquitectura, **nunca** una repetición del síntoma (`El parser de Express 5 no inicializa body si el content-type no es exacto`).
   - **Solución preventiva (Antídoto)**: la regla aplicable a futuro para evitar el error (`Middleware de validación Zod obligatorio antes de invocar la capa de servicio`).
   *Si falta alguno de los tres elementos o la causa es tautológica, solicítala antes de guardar.*
2. **Elegir categoría**: `frontend`, `backend`, `database`, `security`, `devops`, `mobile`, `ai`, `ui/ux` o `domain`.
3. **Control de duplicados**: busca en `BRAIN.md` lecciones similares; si ya existe, actualiza su antídoto en lugar de crear una fila redundante. `task.sh learn` rechaza por sí mismo una lección idéntica a una activa (sin contar tildes, mayúsculas ni puntuación) o que comparte la mayoría de sus palabras; usa `--force` solo si de verdad es distinta.
4. **Registro automático**:
   ```bash
   ./.agents/scripts/task.sh learn "<problema>" <categoría> "<causa raíz>" "<solución>"
   ```
   *Evita el carácter `|` en los textos.*
5. **Trampas y Quirks de Librerías**: si el error proviene de una incompatibilidad de versión de una librería o framework, añade además una fila en la tabla *Quirks y Trampas Conocidas* de `BRAIN.md` §3.
6. **Preferencias de Estilo**: si se trata de una directriz de estilo o convención personal del usuario, regístrala en `.agents/brain/preferences.md`.
7. **Confirmación**: informa al usuario el ID asignado (`LL-XXX`).

## Gestión de Deuda Técnica
Si en lugar de un aprendizaje se trata de una solución provisional aceptada para no bloquear la entrega:
```bash
./.agents/scripts/task.sh debt "<descripción>" TASK-XXX "<acción definitiva>" [ALTA|MEDIA|BAJA]
```

## Mantenimiento del Cerebro
- **Deuda saldada**: cuando la tarea que la corrige queda `DONE`, sáldala con `./.agents/scripts/task.sh debt-resolve TD-XXX` (la marca `SALDADA` en `tech_debt.md`, de modo que su ID no se reutiliza, y la retira del resumen de `BRAIN.md`).
- **Lección que ya no aplica** (se cambió de librería, se eliminó el módulo): retírala con `./.agents/scripts/task.sh lesson-retire LL-XXX`. Queda marcada `OBSOLETA`, deja de mostrarse en `task.sh start` y no bloquea lecciones nuevas parecidas.
- `task.sh start` muestra como recordatorio las lecciones activas de la categoría del agente asignado y, después, las más recientes del resto.

## Checklist antes de registrar lección
- [ ] Lección con las 3 partes obligatorias: Problema observable, Causa raíz técnica y Solución preventiva aplicable.
- [ ] Categoría seleccionada según el ámbito (`backend`, `frontend`, `database`, `security`, etc.).
- [ ] Búsqueda previa en `BRAIN.md` para evitar lecciones duplicadas o contradictorias.
- [ ] Si es deuda técnica, vinculada a una `TASK-XXX` formal y con severidad no crítica.

## Prohibido
- Registrar lecciones tautológicas o vacías (ej. "el código falló porque tenía un bug", "hay que probar mejor").
- Omitir la causa raíz técnica o registrar el síntoma como si fuera la causa.
- Aceptar deuda técnica de prioridad CRÍTICA o que vulnere la seguridad (OWASP) o la integridad de datos.
