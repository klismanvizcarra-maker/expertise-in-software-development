---
name: refactor
description: Reestructura código existente sin cambiar su comportamiento - registra la tarea con prefijo Refactor:, fija el comportamiento actual con tests de caracterización, aplica cambios pequeños y reversibles con la suite en verde tras cada paso y entrega a QA con la prueba de que nada cambió. Usar cuando el usuario pide refactorizar, limpiar, reorganizar, extraer, renombrar, desacoplar o simplificar código que ya funciona, o saldar deuda técnica. No usar para corregir un comportamiento incorrecto (bugfix) ni para añadir funcionalidad (nueva-tarea).
---

# /refactor — Reestructurar sin Cambiar el Comportamiento

Un refactor cambia **la forma** del código, nunca **lo que hace**. Si durante el trabajo aparece un comportamiento incorrecto, se detiene el refactor y ese defecto va por `/bugfix` en una tarea propia.

## Pasos

1. **Delimitar el objetivo**: escribe en una frase qué mejora y cómo se medirá (ej. "extraer el cálculo de impuestos de `OrderService` a `domain/tax.ts`; `OrderService` baja de 600 a menos de 250 líneas"). Sin objetivo medible no hay refactor, hay reescritura.
2. **Consultar el cerebro**: ejecuta `./.agents/scripts/task.sh brain for TASK-XXX <rutas que vas a tocar>` y revisa la deuda técnica vinculada (`.agents/brain/tech_debt.md`). Si el refactor salda una deuda `TD-XXX`, cítala en la tarea.
3. **Registrar la tarea** (si no existe), con el prefijo que crea la rama `refactor/`:
   ```bash
   ./.agents/scripts/task.sh add "Refactor: <qué y dónde>" "<agente dueño de esas rutas>" "Comportamiento idéntico: suite y tests de caracterización en verde antes y después; <objetivo medible>"
   ./.agents/scripts/task.sh start TASK-XXX
   ```
   El agente asignado es el dueño de las rutas según `AGENTS.md` §8. Si el refactor cruza capas, divídelo en una tarea por especialista.
4. **Fijar el comportamiento actual (red de seguridad)**: antes de mover una línea, ejecuta la suite y anota el resultado. Si el código a tocar no tiene tests suficientes, escribe **tests de caracterización**: llaman al código real con entradas representativas (incluidos casos límite y errores) y comprueban la salida **que produce hoy**, aunque parezca rara. Haz commit de estos tests solos (`task.sh commit TASK-XXX "anadir tests de caracterizacion de <modulo>" test`).
5. **Cambiar en pasos pequeños**: un movimiento por paso (extraer función, renombrar, mover archivo, invertir una dependencia). Tras **cada** paso la suite completa sigue en verde; si se pone en rojo, deshaz ese paso en lugar de arreglar hacia delante. Un commit por paso significativo.
6. **Verificar la equivalencia**:
   - Tests de caracterización y suite completa en verde, sin modificar ninguna aserción.
   - Contratos públicos intactos: firmas exportadas, endpoints, formato de respuestas y esquema de base de datos. Si alguno debe cambiar, eso ya no es un refactor: para y crea la tarea que corresponda.
   - Build, tipado y lint sin errores nuevos; el objetivo medible del paso 1 se cumple.
   - `./.agents/scripts/scan-secrets.sh --branch` limpio.
7. **Entregar**: ejecuta `/handoff` con el antes y el después del objetivo medible y los comandos para comprobar que el comportamiento no cambió. Si saldaste una deuda, indícalo para que se cierre con `task.sh debt-resolve TD-XXX` tras la aprobación.

## Checklist antes de `task.sh handoff`
- [ ] Objetivo medible declarado en la tarea y cumplido (cifra antes y después).
- [ ] Tests de caracterización escritos **antes** del primer cambio y commiteados por separado.
- [ ] Suite completa en verde tras cada paso; ninguna aserción existente modificada.
- [ ] Contratos públicos (APIs, firmas exportadas, esquema de BD, formatos) sin cambios.
- [ ] Ningún cambio de comportamiento ni corrección de bugs mezclada en el diff.
- [ ] Escaneo de secretos limpio (`./.agents/scripts/scan-secrets.sh --branch`).

## Prohibido
- Cambiar el comportamiento observable "de paso", aunque parezca una mejora o la corrección de un bug evidente.
- Modificar, borrar o relajar la aserción de un test para que pase tras el refactor.
- Refactorizar código sin red de seguridad (sin tests que cubran lo que se toca).
- Mezclar en la misma tarea un refactor con funcionalidad nueva o con un bugfix.
- Reescrituras completas encubiertas como refactor: si no se puede hacer en pasos pequeños con la suite en verde, se planifica como tarea nueva con el `orchestrator-agent`.
