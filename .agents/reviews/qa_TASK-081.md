# Veredicto de QA: TASK-081

- **Tarea**: `TASK-081` — Fix: descripciones de skills superan el presupuesto del listado de Claude Code y 18 skills aparecen sin descripción
- **Fecha**: 2026-11-20
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `docs-architecture-agent`
- **Resultado**: `APROBADA`
- **Iteración**: `2/3` (rechazo 1/3 por BUG-TASK-081-1, `docs/qa/BUG-TASK-081-1.md`)

> Ambas iteraciones las revisó un subagente con contexto limpio, conforme a AGENTS.md §4.2.

---

## 1. Criterios de Aceptación Verificados

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| Topes acordados y documentados | ✅ | `MAX_DESC_CHARS=300`, `MAX_TOTAL_CHARS=15000` en `lint_descriptions.py`; documentados en `tests/triggers/README.md`, `preferences.md`, `stack_template.md` y CHANGELOG |
| Descripciones compactadas | ✅ | Medición propia: 56 skills, 14 863 caracteres (antes 31 495), máximo 300; YAML válido (Ruby `YAML.safe_load`); solo cambian líneas `description` |
| El linter falla al superar los topes (test en tests/) | ✅ | 6 checks nuevos en `test-scripts.sh` que comprueban exit y mensaje; 24 intentos de esquivarlo (orden de claves, claves extra, `>`/`|`, comillas, CRLF, BOM, sin cierre) fallan midiendo o nombrando la SKILL.md |
| 56 skills con descripción en una sesión nueva | ✅ | El listado de skills de la sesión del revisor (nueva) muestra las 56 con descripción y el texto nuevo |
| test-skills.sh y lint_descriptions.py en verde | ✅ | 56 skills sin errores; "Sin problemas", 14863/15000 |
| Lección | ✅ | LL-020 ACTIVA con ámbito `.agents/skills/*/SKILL.md`, antídoto ampliado tras el rechazo |
| Límites entre skills | ✅ | Los 10 límites pedidos en el rechazo restaurados; los recortes compensatorios no pierden límites críticos |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` sin hallazgos |
| Batería de pruebas | ✅ | test-scripts 388 OK, test-flow 25 OK, validate-state 0 advertencias, brain doctor sano |
| Auditoría de seguridad | ✅ | No aplica OWASP: cambios en descripciones, linter y tests |

## 2. Observaciones y Hallazgos

- **Observaciones (BAJA)**: el linter no suma la clave `when_to_use` (Claude Code la concatena a la descripción en el listado) y no cubre alias YAML, claves duplicadas ni UTF-8 inválido (traceback en lugar de mensaje). Hoy ninguna skill usa esas formas. Límites no críticos perdidos: cerrar-fase → nueva-tarea, orchestrator "escribir código", "No usar" en stack-nestjs/vue-nuxt/react-native-expo (se distinguen por tecnología).
- **Deuda Técnica**: registrada con `task.sh debt` (BAJA): medir `when_to_use` y mostrar un mensaje ante UTF-8 inválido.
- **Lección**: `LL-020` (tarea de corrección con un rechazo). La reincidencia de LL-020 que anotó `reject` era un falso positivo (la lección nació en esta tarea) y se retiró de `recurrences.md`.

## 3. Conclusión y Veredicto Final

- **Estado**: `APROBADA`
- **Siguiente paso**: `task.sh close TASK-081 --lesson LL-020` y fusión `--no-ff` a main.
