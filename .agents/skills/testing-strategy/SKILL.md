---
name: testing-strategy
description: Diseña la estrategia y arquitectura de pruebas unitarias, de integración y de contrato - trofeo/pirámide de testing, uso de fakes reales frente a mocks acoplados, aislamiento de base de datos por test, validación de contratos Zod/OpenAPI, relojes/semillas deterministas y eliminación de flakiness. Usar al planificar o escribir pruebas unitarias y de integración, desacoplar tests frágiles o estabilizar suites lentas e inestables. No usar para flujos E2E completos en navegador (e2e-testing) ni para emitir el veredicto QA sobre una entrega (qa-review, qa-security-agent).
---

# Estrategia de Pruebas (Testing Strategy)

Las pruebas deben validar **comportamiento observable**, ejecutarse en segundos sin depender del orden ni de red real, y fallar solo cuando cambia una regla de negocio o un contrato. La carga el especialista que implementa junto con su rol y su stack.

## Pasos

1. **Definir la proporción por riesgo (Trofeo de Testing)**:
   - **Unitarias puras (`domain/`)**: reglas, máquinas de estado, cálculos monetarios y validadores sin I/O ni mocks.
   - **Integración (servicios + HTTP + BD real)**: rutas y repositorios contra PostgreSQL/SQLite de pruebas con migraciones aplicadas y aislamiento entre casos.
   - **Contrato (entre capas/servicios)**: esquemas Zod, JSON Schema o OpenAPI generados verificados entre emisor y receptor; los flujos E2E críticos los cubre `e2e-testing`.
2. **Elegir el doble adecuado** (ver [unit-integration-contracts.md](references/unit-integration-contracts.md)):
   - Prefiere el código real o un *fake* en memoria fiel al contrato (p. ej. repositorio en memoria, reloj inyectado) antes que `vi.fn()`/`MagicMock` sobre métodos privados.
   - Simula únicamente las fronteras externas no deterministas (pasarelas HTTP externas, email, reloj del sistema, generadores aleatorios).
3. **Aislar base de datos y estado entre tests**:
   - Cada test arranca limpio (transacción revertida en `afterEach`/fixture, `TRUNCATE ... RESTART IDENTITY CASCADE` o esquema por worker paralelo) y crea sus propios datos mediante *factories* explícitas (`buildOrder({ status: 'PAID' })`), nunca con semillas compartidas mutables.
4. **Blindar el determinismo (cero flakiness)**:
   - Inyecta `clock` / `now()`, `random()` y UUIDs deterministas.
   - Prohibido usar `sleep` / `setTimeout` arbitrarios: sincroniza mediante promesas, contadores de cola drenada o eventos explícitos.
5. **Validar contratos API y regresiones**:
   - Toda ruta prueba al menos: caso feliz (`200`/`201`), payload inválido (`400`/`422`), no autenticado (`401`), sin permiso/IDOR (`403`/`404`) y conflicto/duplicado (`409` o idempotencia).
6. **Entrega**: ejecuta la suite en paralelo y repetida sin flakiness antes de `/handoff`.

## Checklist antes de `task.sh handoff`
- [ ] Reglas puras de dominio cubiertas por unitarias sin base de datos ni HTTP.
- [ ] Endpoints críticos probados por integración contra migraciones reales y con limpieza/aislamiento por test.
- [ ] Aserciones sobre resultados, estado persistido o respuesta HTTP; sin aserciones frágiles a llamadas internas privadas.
- [ ] Tiempo, aleatoriedad y red externa controlados (sin peticiones HTTP reales salientes ni `sleep` fijos).
- [ ] Casos límite y códigos de error (`400`/`401`/`403`/`404`/`409`) probados junto al caso feliz.
- [ ] Suite ejecutada en verde repetidamente sin depender del orden de ejecución (`--shuffle` o 2 corridas seguidas).

## Prohibido
- Mockear el módulo bajo prueba o verificar solo el orden de llamadas internas ignorando la salida o el estado real.
- Compartir registros mutables entre tests haciendo que el orden de ejecución altere el resultado.
- Usar `sleep` / esperas temporales ciegas o llamadas de red reales a terceros dentro de unitarias e integración.
- Multiplicar tests E2E en navegador para cubrir validaciones que se prueban en milisegundos con integración/unitarias (ver `e2e-testing`).
