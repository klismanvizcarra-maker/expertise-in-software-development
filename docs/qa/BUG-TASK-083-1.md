# BUG-TASK-083-1 — Evals nuevas: temporales huérfanos, trampas no detectadas y falsos negativos

- **Tarea**: TASK-083 · **Iteración**: 1/3 · **Revisor**: devops-cloud-agent (protocolo qa-security-agent) · **Severidad máxima**: MEDIA

| # | Severidad | Defecto | Reproducción |
| :- | :- | :--- | :--- |
| 1 | MEDIA | `resilience_checks.mjs mutants` llama a `process.exit` dentro de `try/finally`: cada fallo deja una copia `resilience-mutant-*` en el temporal (como TD-006) | `make_project` + setup de `payment_client.sh` + `node "$FIXTURES/resilience_checks.mjs" mutants` → exit 1 y un `resilience-mutant-*` más |
| 2 | MEDIA | `finops_check.py sql` acepta `event_date` en `GROUP BY`, en una subconsulta del SELECT o en un comentario `/* */` (escaneo completo de 40 TB); tampoco ve `SELECT DISTINCT *` | `... WHERE e.event_type='purchase' GROUP BY e.event_date` pasa |
| 3 | MEDIA | El check `breaker` usa `maxRetries: 0`: no separa fallos por intento de fallos por llamada, timeout por intento de timeout global, ni una prueba HALF_OPEN única de dejar pasar todas; no prueba ECONNREFUSED | breaker que suma un fallo por intento pasa |
| 4 | MEDIA | Falso negativo: `<label>Correo <input type="email" name="email"></label>` (sin id) se rechaza | `a11y_check.py` → "campo (sin id) sin <label> visible asociado" |
| 5 | BAJA-MEDIA | Falsos negativos de `.hint`: selector agrupado `.hint, .note {` y color `rgb(118, 118, 118)` | "no se encuentra el color de .hint" |
| 6 | BAJA-MEDIA | Falso negativo de `mutants` si los tests usan una clase en vez de `createResilientCaller` (los criterios no lo exigen) | tests con `new ResilientCaller()` → "siguen en verde" |
| 7 | BAJA | No detecta label oculto (`display:none`), `.hint` sobrescrito por `form p.hint`, alt "imagen del logo"; exige un h1 inicial no dicho en los criterios | — |
| 8 | BAJA | El informe acepta cualquier número a ±10 % (aunque no sea el ahorro); `storageClass: "standard"` en minúsculas cuenta como barata; el SQL exige "purchase" sin decirlo en los criterios | — |

## Esperado
Checks que limpian sus temporales también al fallar; reglas de sintaxis acotadas a su cláusula o elemento real; valores de prueba que separen las implementaciones candidatas; criterios que fijen cada regla comprobada; cada caso nuevo en la matriz de `tests/test-scripts.sh`.
