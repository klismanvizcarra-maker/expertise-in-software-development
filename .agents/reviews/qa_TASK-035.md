# Veredicto de QA: TASK-035

- **Tarea**: `TASK-035`
- **Fecha**: 2026-11-10
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `APROBADA`
- **Iteración**: `1/3`

---

## 1. Criterios de Aceptación Verificados

Revisión con contexto limpio (subagente independiente). Las pruebas manuales se hicieron en proyectos temporales creados con `init-project.sh`, fuera del repositorio, con `/bin/bash` 3.2.57.

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| `norm_text` funciona sin python3 en locale C (salda TD-002, test con PATH sin python3) | ✅ | Con un PATH sin `python3`, `learn` rechaza el duplicado en mayúsculas y el duplicado sin tildes en las 8 combinaciones (con/sin python3 × `LC_ALL=C`/`es_ES.UTF-8`) y acepta una lección distinta. TD-002 marcada `SALDADA` en `tech_debt.md`. Tests nuevos en `tests/test-scripts.sh` |
| Slug de rama igual con y sin python3 | ✅ | Mismo slug en las 4 combinaciones para tildes, ñ, ü, ç, mayúsculas, símbolos ASCII (`% & + / ( ) # @ $ \n %s`), `¿ ¡`, texto NFD y CJK. Divergen solo caracteres fuera del mapa (ver observación 1) |
| `init-project.sh "Nombre"` con un solo argumento en bash 3.2 | ✅ | `/bin/bash init-project.sh "Solo Nombre Ñ"` → rc=0 e instala en el directorio actual con el nombre correcto; sin argumentos → rc=0 con `Nuevo Proyecto`; `--update` sin argumentos y `--stack angular "Nombre"` → rc=0 |
| `say`/`die` no interpretan secuencias de escape del usuario | ✅ | Texto con `\n \t \x41 \101 %s %d %n $(touch PWNED) \033[31m \c` sale literal (verificado con `od -c`) en `add`, `learn`, `debt`, `reject`, `commit` y en los errores de `start`, `move` y `learn`; no se ejecutó ningún comando. Con pseudo-terminal los colores salen con ESC real (`033 [ 0 ; 3 2 m`); sin terminal, 0 bytes ESC. El mensaje de uso de `die` conserva su salto de línea |
| `append_to_table` conserva los permisos del archivo | ✅ | Ciclo completo (`add`, `start`, `commit`, `handoff`, `reject`, `close`, `move`, `learn`, `debt`, `debt-resolve`, `lesson-retire`) con 644, 600 y 664: permisos e inodo idénticos antes y después en `GLOBAL_STATE.md`, `BRAIN.md`, `tech_debt.md` y `lessons_learned.md`. No queda ningún `mv` a archivos del proyecto ni temporales en el camino de éxito |
| `debt-resolve` detecta SALDADA solo en la columna de prioridad | ✅ | Una deuda con `SALDADA` en descripción y en acción se salda la primera vez; la segunda da "ya estaba marcada como SALDADA"; ID inexistente da error; la fila se retira de `BRAIN.md` |
| Tests nuevos | ✅ | Sección "robustez de task.sh" con 10 comprobaciones nuevas |
| Suite al 100% | ✅ | `test-scripts.sh` 157 OK / 0 fallidas; `test-flow.sh` 24 OK / 0 fallidas; `test-skills.sh` 28 skills sin errores; `validate-state.sh` sin errores (0 advertencias) |
| Escaneo de secretos | ✅ | `./.agents/scripts/scan-secrets.sh --branch` sin hallazgos |
| Auditoría de seguridad | ✅ | El cambio reduce superficie (se elimina `printf %b` sobre texto del usuario). Sin inyección de comandos ni de formato |
| Regresiones en `add`, `start`, `handoff`, `reject`, `close`, `move`, `commit` | ✅ | Ciclo completo ejecutado tres veces hasta `DONE`; `validate-state.sh` rc=0 al final |

## 2. Observaciones y Hallazgos

- **Observaciones (BAJA)**:
  1. Sin python3, `norm_text` solo cubre los caracteres de su mapa. `º`, `ª`, `å`, `ý`, `ÿ` dan resultados distintos: "Paso 1º y 2ª opción" produce `paso-1o-y-2a-opcion` con python3 y `paso-1-y-2-opcion` sin él. Como `start` recalcula el slug al retomar, una tarea iniciada en una máquina y retomada en otra sin python3 crearía una rama nueva en lugar de volver a la suya. Ya ocurría antes del cambio (no es regresión). Sugerencia: añadir `º`/`ª` al mapa o localizar la rama existente por `*/TASK-XXX-*`.
  2. `replace_file` (`cat tmp > file`) no es atómico como `mv`: una interrupción a mitad de escritura (señal, disco lleno) puede dejar el archivo truncado, y un lector que no toma el lock puede ver un contenido parcial. El lock excluye a otros escritores de `task.sh`, los archivos son pequeños y están en git, por lo que el riesgo es bajo. A cambio conserva permisos, inodo y enlaces. Alternativa atómica: copiar el modo al temporal y usar `mv`.
  3. Si la escritura falla (probado con el archivo en 444), el original queda intacto y el lock se libera, pero el temporal de `mktemp` queda huérfano en el directorio temporal del usuario (no en el proyecto). Antes, `mv` sobrescribía un archivo de solo lectura; ahora se respeta.
  4. No hay test automatizado para permisos 600 ni para colores con terminal; se verificaron a mano.
- **Deuda Técnica**: ninguna registrada.

## 3. Conclusión y Veredicto Final

- **Estado**: `APROBADA`
- **Siguiente paso**: `task.sh close TASK-035`
