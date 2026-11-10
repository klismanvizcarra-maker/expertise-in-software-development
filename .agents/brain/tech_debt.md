# Registro de Deuda Técnica Aceptada (Technical Debt Register)

> **Propósito**: Documentar soluciones temporales (*workarounds*) o compromisos técnicos aceptados durante el desarrollo para evitar que se conviertan en defectos ocultos o bugs silenciosos a largo plazo.

---

## 1. Tablero de Deuda Técnica

| ID | Tarea Vinculada | Fecha | Módulo | Descripción de la Deuda | Solución Temporal Aplicada | Acción Definitiva Pendiente | Prioridad |
| :---: | :---: | :---: | :--- | :--- | :--- | :--- | :---: |
| `TD-001` | `TASK-029` | 2026-11-10 | General | task.sh commit acepta trailers multilinea: la validacion no rechaza saltos de linea y rompe el bloque de trailers | Workaround temporal | Rechazar trailers con salto de linea (anclar el patron y comprobar una sola linea) y anadir test en tests/test-scripts.sh | `SALDADA` |
| `TD-002` | `TASK-030` | 2026-11-10 | General | task.sh learn: sin python3 y en locale C el detector de duplicados queda desactivado en silencio (el sed y/// de norm_text falla con caracteres multibyte y devuelve vacio) | Workaround temporal | Hacer el camino sin python3 de norm_text independiente del locale (o degradar a tr sin quitar tildes si sed falla) y anadir test con PATH sin python3 | `MEDIA` |

---

## 2. Criterios de Aceptación de Deuda Técnica
1. **Solo severidad Media o Baja**: Queda terminantemente prohibido aceptar deuda técnica que comprometa la seguridad (OWASP), vulnere la privacidad de datos o cause crashes del servidor.
2. **Tarea vinculada obligatoria**: Toda deuda técnica debe estar asociada a una tarea formal (`TASK-XXX`).
3. **Revisión periódica**: El `orchestrator-agent` debe revisar este tablero al inicio de cada nueva fase del proyecto para planificar tareas de refactorización y saneamiento.
