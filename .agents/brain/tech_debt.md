# Registro de Deuda Técnica Aceptada (Technical Debt Register)

> **Propósito**: Documentar soluciones temporales (*workarounds*) o compromisos técnicos aceptados durante el desarrollo para evitar que se conviertan en defectos ocultos o bugs silenciosos a largo plazo.

---

## 1. Tablero de Deuda Técnica

| ID | Tarea Vinculada | Fecha | Módulo | Descripción de la Deuda | Solución Temporal Aplicada | Acción Definitiva Pendiente | Prioridad |
| :---: | :---: | :---: | :--- | :--- | :--- | :--- | :---: |
| `TD-001` | `TASK-001` | 2026-10-10 | Backend | Paginación en memoria en endpoint de listado | Retorna array completo acotado a 100 registros | Implementar paginación SQL con `LIMIT / OFFSET` y cursor | `MEDIA` |
| `TD-002` | `TASK-008` | 2026-10-29 | General | scan-secrets.sh: rutas con comilla doble o barra invertida (git las sigue entrecomillando con core.quotePath=false) escapan a --staged, --all y al repaso por archivo de --branch; un .env creado por rename y las lineas que empiezan por '++ ' escapan al repaso del historial | Workaround temporal | Listar y leer rutas con -z (diff/ls-files/log -z) y detectar .env con --diff-filter=AR; anadir tests | `MEDIA` |

---

## 2. Criterios de Aceptación de Deuda Técnica
1. **Solo severidad Media o Baja**: Queda terminantemente prohibido aceptar deuda técnica que comprometa la seguridad (OWASP), vulnere la privacidad de datos o cause crashes del servidor.
2. **Tarea vinculada obligatoria**: Toda deuda técnica debe estar asociada a una tarea formal (`TASK-XXX`).
3. **Revisión periódica**: El `orchestrator-agent` debe revisar este tablero al inicio de cada nueva fase del proyecto para planificar tareas de refactorización y saneamiento.
