# Veredicto de QA: [TASK-XXX]

- **Tarea**: `[TASK-XXX]`
- **Fecha**: YYYY-MM-DD
- **Revisor**: `[qa-security-agent]`
- **Especialista Asignado**: `[agente-asignado]`
- **Resultado**: `[APROBADA | RECHAZADA]`
- **Iteración**: `[1/3 | 2/3 | 3/3]`

---

## 1. Criterios de Aceptación Verificados

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| [Criterio 1] | ✅ | [Comando, test o evidencia verificable] |
| Escaneo de secretos | ✅ | `./.agents/scripts/scan-secrets.sh --branch` limpio |
| Batería de pruebas | ✅ | Tests pasando al 100% |
| Auditoría de seguridad | ✅ | Sin vulnerabilidades OWASP ni IDOR |

## 2. Observaciones y Hallazgos

- **Observaciones (BAJA)**: [Detalles no bloqueantes si aplican]
- **Deuda Técnica**: [Registrada con task.sh debt si aplica]

## 3. Conclusión y Veredicto Final

- **Estado**: `[APROBADA | RECHAZADA]`
- **Siguiente paso**: `[task.sh close TASK-XXX | task.sh reject TASK-XXX "<motivo>"]`
