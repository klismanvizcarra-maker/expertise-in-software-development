# Preferencias y Convenciones de la Librería SKILL MAESTRO (Preferences)

> **Propósito**: Convenciones vinculantes para todo agente que modifique **esta librería** (skills, scripts, plantillas y pruebas). No son las preferencias de los proyectos que la instalan: esos parten de `.agents/templates/preferences_template.md`.
>
> **Origen**: convenciones observadas en el repositorio y en las revisiones de QA. Si el desarrollador indica otra preferencia, se registra aquí con `/aprender`.

---

## 1. Idioma y Redacción
- **Español** en skills, documentación, mensajes de los scripts y descripciones de tareas.
- **Mensajes de commit sin tildes ni eñes** (`anadir`, `correccion`), en imperativo y con el formato `tipo(TASK-XXX): descripción`.
- Las `description` de las skills dicen qué hace, cuándo usarla y **cuándo no** (con la skill vecina correcta entre paréntesis).

## 2. Scripts (`.agents/scripts/`, `tests/`)
- **Portabilidad obligatoria**: bash 3.2 de macOS y bash de Ubuntu; awk y sed BSD y GNU. Sin `mapfile`, sin arrays asociativos, sin extensiones GNU (`\s`, `sed -i` sin sufijo, `grep -P`).
- **Dependencias**: solo `git` y `python3`. No se añaden otras sin un ADR.
- **Sin efectos fuera del proyecto**: las pruebas trabajan en directorios temporales (`mktemp -d`) con `trap` de limpieza; nunca en el repositorio.
- **Errores explícitos**: un script que no puede hacer su trabajo sale con código distinto de 0 y un mensaje accionable; no se silencia `stderr` de una tubería cuyo resultado vacío cambia el comportamiento.
- **Texto del usuario como dato**: se escapa al escribirlo en tablas Markdown (`cell`), en JSON (`json_escape`) y en reemplazos de `sed`.

## 3. Pruebas y Calidad
- **Todo cambio de script lleva su prueba** en `tests/test-scripts.sh` o `tests/test-flow.sh`, y la prueba debe fallar con el código anterior.
- **Toda skill nueva o `description` cambiada** pasa `tests/test-skills.sh` y `tests/triggers/lint_descriptions.py`, y añade casos a `tests/triggers/cases.json`.
- El número de comprobaciones citado en `QUICKSTART.md` se actualiza cuando cambia.

## 4. Plantillas frente a Instancia
- Lo que hay en `.agents/templates/` es **genérico** y se copia a los proyectos; no debe contener lecciones, deudas ni preferencias de esta librería.
- `BRAIN.md`, `GLOBAL_STATE.md` y `.agents/brain/` de la raíz son **la instancia de la librería** y describen solo su propio desarrollo.

## 5. Stack de Referencia del Desarrollador
- Para proyectos web propios: Angular + Express + PostgreSQL con Drizzle, JWT propio y monorepo npm (skill `stack-angular-express-postgres`). Las demás skills `stack-*` son alternativas soportadas.
