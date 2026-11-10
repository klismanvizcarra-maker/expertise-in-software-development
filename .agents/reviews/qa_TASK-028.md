# Veredicto de QA: TASK-028

- **Tarea**: `TASK-028`
- **Fecha**: 2026-11-10
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `docs-architecture-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `1/3`

---

## 1. Criterios de Aceptación Verificados

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| Skill con SKILL.md y 2 referencias | ✅ | Presentes; ejemplos correctos SQLAlchemy 2 / Pydantic v2 / FastAPI |
| Versiones contrastadas con PyPI | ✅ | fastapi 0.162.2, uvicorn 0.54.0, pydantic 2.14.3, sqlalchemy 2.1.8, alembic 1.20.1, psycopg 3.3.8, pytest 9.2.0, httpx 0.28.1, ruff 0.17.4 |
| AGENTS.md §8 mapea rutas | ✅ | Bloque `stack-fastapi-postgres` añadido |
| init-project.sh --stack fastapi sin placeholders | ❌ | `GLOBAL_STATE.md` generado conserva `[Plataforma: ej. Docker / Vercel / Render / AWS]` y la línea de Infraestructura queda corrupta; Descripción sin backtick de cierre |
| 2 casos en cases.json | ✅ | stk-04, stk-05 (no ejecutados contra Claude real; aceptable) |
| test-skills / lint / suite | ✅ | 123 OK 0 fallidas; lint sin problemas; scan-secrets limpio |

## 2. Hallazgos

- **BUG-TASK-028-1 (MEDIA)**: en `init-project.sh` el reemplazo sed de `Infraestructura & Despliegue` usa `&` sin escapar; en sed `&` = texto coincidente, así que la línea resultante es
  `- **Infraestructura - **Infraestructura & Despliegue**: `[Plataforma: ...]` Despliegue**: `Docker multi-etapa / uvicorn / VPS``.
  Reproducción: `git init /tmp/x && ./.agents/scripts/init-project.sh "A" /tmp/x --stack fastapi && sed -n 24p /tmp/x/GLOBAL_STATE.md`.
  Corrección: escapar `\&` en la rama fastapi (idealmente también en nextjs/angular, defecto heredado).
- **BUG-TASK-028-2 (BAJA)**: el patrón `[Breve descripción.*` consume el resto de línea incluido el backtick de cierre; la Descripción queda sin cerrar.
- **BUG-TASK-028-3 (BAJA)**: el test "sin placeholders" solo busca 2 patrones y no detectó lo anterior; ampliarlo (p. ej. `\[Plataforma`).
- **Obs. (BAJA)**: SKILL.md pide IDs `uuid` pero los ejemplos usan `int`.

## 3. Conclusión
- **Estado**: `RECHAZADA`
- **Siguiente paso**: `task.sh reject TASK-028`; el especialista corrige y reentrega.
