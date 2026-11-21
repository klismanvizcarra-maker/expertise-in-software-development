# Soluciones de referencia de las evals

Una solución correcta por eval, usada solo por `tests/test-scripts.sh` para comprobar sin LLM que los checks de `tests/evals/evals.json` **aceptan** una solución correcta y **rechazan** las trampas típicas (LL-017). No se copian al proyecto temporal de la eval: el modelo nunca las ve.

| Carpeta | Eval |
| :--- | :--- |
| `resilience-pagos-breaker/` | Caller con timeout, reintentos con backoff exponencial y jitter, y circuit breaker |
| `accessibility-wcag-formulario/` | `signup.html` corregido y `test/a11y.test.js` que detecta las violaciones |
| `finops-rightsizing-logs/` | Función redimensionada, ciclo de vida de logs, consulta por partición e informe con el ahorro |
