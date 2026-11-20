---
name: incidente
description: Coordina la gestión integral y contención de un incidente crítico en producción (caída de servicio, degradación severa, fuga de datos o fallos masivos) - evalúa severidad, activa medidas de mitigación inmediata (rollback o degradación graciosa), canaliza la solución técnica mediante /hotfix y lidera el análisis post-mortem. Usar cuando se declare una alerta SEV-1, SEV-2 o indisponibilidad en producción para restablecer el servicio de forma metódica. No usar para bugs menores de desarrollo (usar bugfix) ni para tareas programadas de mantenimiento.
---

# /incidente — Gestión y Contención de Incidentes en Producción

La skill de flujo `/incidente` gobierna la respuesta ante crisis operativas en producción. Asume el rol de **Comandante del Incidente** (`devops-cloud-agent` / SRE) para priorizar el restablecimiento del servicio sobre la investigación exhaustiva.

---

## Protocolo

1. **Declaración y Triage (Minutos 0 a 5)**:
   - Asigna nivel de severidad:
     - **SEV-1**: Caída total o degradación de funciones críticas (pagos, autenticación, pérdida de datos).
     - **SEV-2**: Pérdida parcial de funcionalidad con workaround disponible o degradación de latencia severa.
     - **SEV-3**: Defecto visible en producción con impacto localizado en pocos usuarios.
   - Establece un canal único de comunicación y designa al comandante del incidente.

2. **Mitigación Inmediata (Contener antes de investigar)**:
   - **Regla de Oro**: Si el último despliegue causó el problema, ejecuta **rollback inmediato** al tag previo (`git checkout <tag-anterior>` o rollback en cloud) antes de intentar entender el código.
   - Si el problema es sobrecarga de base de datos o API externa:
     - Activa modo mantenimiento o desactiva feature flags problemáticas.
     - Habilita rate limiting estricto o fallbacks degradados (respuestas cacheadas o respuestas estáticas).

3. **Diagnóstico Asistido por Observabilidad**:
   - Revisa logs estructurados con `request_id`, métricas RED (tasa de errores, latencia p99) y trazas de OpenTelemetry.
   - Identifica el commit, migración o cambio de infraestructura detonante.

4. **Canalización de la Solución**:
   - Si la mitigación requiere cambio de código o configuración versionada, delega la creación del parche al flujo `/hotfix`.
   - Una vez desplegado el parche, ejecuta pruebas de humo en caliente (`/healthz`, `/readyz` y flujos críticos).

5. **Post-Mortem y Cierre de Incidente**:
   - Convoca la retrospectiva del incidente sin buscar culpables (*blameless post-mortem*).
   - Redacta el reporte usando `.agents/templates/post_mortem_template.md`.
   - Registra lecciones aprendidas en el cerebro con `./.agents/scripts/task.sh learn` y planifica tareas preventivas con `/nueva-tarea`.

---

## Checklist

- [ ] Severidad del incidente clasificada formalmente (SEV-1, SEV-2 o SEV-3).
- [ ] Medida de contención inmediata aplicada (rollback, flag apagada o fallback).
- [ ] Servicio confirmado en estado operativo mediante endpoints de salud (`/healthz`).
- [ ] Si se requirió código, se gestionó mediante el flujo `/hotfix`.
- [ ] Causa raíz analizada mediante la técnica de los 5 porqués.
- [ ] Informe post-mortem redactado y archivado en `docs/incidents/`.
- [ ] Al menos una acción preventiva registrada como lección o tarea futura.

---

## Prohibido

- Prohibido depurar código en vivo en producción mientras el servicio siga caído sin haber intentado rollback primero.
- Prohibido cerrar un incidente SEV-1 o SEV-2 sin haber redactado el post-mortem correspondiente.
- Prohibido buscar culpables individuales: el análisis post-mortem debe centrarse en fallos del sistema y procesos.
- Prohibido dejar mitigaciones temporales (workarounds o flags apagadas) sin registrarlas en el registro de deuda técnica (`task.sh debt`).
