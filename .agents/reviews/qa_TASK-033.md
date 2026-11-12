# Veredicto de QA: TASK-033

- **Tarea**: `TASK-033`
- **Fecha**: 2026-11-11
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `docs-architecture-agent`
- **Resultado**: `APROBADA`
- **Iteración**: revisión 2 tras la reapertura (contador `1/3` tras el rechazo por BUG-TASK-033-7); revisión acotada con contexto limpio del commit `1ee822e`

---

## 1. Criterios de Aceptación y Controles

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| Skills con referencias, Checklist y Prohibido; AGENTS.md §2.7; casos de activación | ✅ | Sin cambios en esta iteración salvo la sección SSRF (`git diff HEAD~1 --stat`); dados por buenos en veredictos anteriores |
| `test-skills.sh` | ✅ | Ejecutado: 32 skills auditadas sin errores |
| `lint_descriptions.py` | ✅ | Ejecutado: "Sin problemas" |
| `test-scripts.sh` | ✅ | Ejecutado: 239 OK, 0 fallidas |
| `validate-state.sh` | ✅ | Ejecutado: 0 advertencias |
| Escaneo de secretos | ✅ | Ejecutado `scan-secrets.sh --branch` (respecto a `main` 984d0fb): sin hallazgos |
| BUG-7 Node: IPv6 literal entre corchetes | ✅ | Ejecutado Node 24.21, receta implementada tal como la escribe `checklist.md` (`new URL()`, quitar corchetes, `net.isIP`, `http.Agent({ lookup })` que respeta `{ all: true }`, redirecciones seguidas a mano por todo el proceso). Servidor local en `::`. Bloqueados sin conectar (`lookup` 0 llamadas): `127.0.0.1`, `2130706433`, `0177.0.0.1`, `0x7f.1`, `169.254.169.254`, `[::1]`, `[::ffff:127.0.0.1]`, `0.0.0.0`, `0`, `127.1`, `[::]`, `[0:0:0:0:0:ffff:7f00:1]`, `[64:ff9b::7f00:1]`, `[2002:7f00:1::]`, `127.0.0.1.`, `0x7F000001`, `017700000001`, `[::ffff:a9fe:a9fe]`. `localhost`, `LOCALHOST`, `localhost.` bloqueados por el `lookup` (1 llamada). Zona `%25` (`[fe80::1%25lo0]`, `[::1%25lo0]`): `new URL()` lanza `ERR_INVALID_URL` |
| Redirección a cada IP literal interna | ✅ | Ejecutado: origen `pub.test` (lookup falso → `93.184.216.34`) responde 302 a `127.0.0.1`, `2130706433`, `0177.0.0.1`, `0x7f.1`, `169.254.169.254`, `[::1]`, `[::ffff:127.0.0.1]`, `0.0.0.0`: las 8 bloqueadas como literal en el segundo salto |
| Destino público simulado | ✅ | Ejecutado: `pub.test` → `93.184.216.34` pasa la validación (200; un adaptador de test redirige la conexión al servidor local tras validar) |
| BUG-7 Python: normalización y camino `getaddrinfo` | ✅ | Ejecutado Python 3.9.6 solo stdlib: `urlsplit` quita corchetes y pasa a minúsculas, pero deja `2130706433`, `0x7f.1`, `0177.0.0.1` y `127.0.0.1.` tal cual (confirma el texto). Literales con `ip_address` bloqueados (`127.0.0.1`, `169.254.169.254`, `::1`, `::ffff:127.0.0.1`, `0.0.0.0`, `::`, NAT64, 6to4, `fe80::1%25lo0`, `ff02::1`, `224.0.0.1`); si `ip_address` falla, `getaddrinfo` + validación bloquea `2130706433`, `0x7f.1`, `0`, `127.1`, `0x7F000001`, `017700000001`, `127.0.0.1.`, `localhost`, `LOCALHOST`, `localhost.`. `0177.0.0.1` → macOS lo lee como `177.0.0.1` (pública): pasa, pero se conecta a esa IP validada, no a loopback; es justo la advertencia del texto. `pub.test` falso → pasa |
| Coherencia con el resto de la tarea (`git diff main...HEAD`) | ✅ | Leído: `SKILL.md` paso 6 resume ahora "host de IP literal validado directamente" y tests IPv4 e IPv6; la línea "Comprobación" añade `[::ffff:127.0.0.1]` y `0x7f.1`; ninguna otra skill del diff (observability, devops, qa-security, web-performance, triggers) habla de SSRF. `seo-web` §5 trata hosts permitidos del SSR, no contradice |
| LL-011 recoge los casos | ✅ | Leído y ejecutado `task.sh brain search corchetes`: antídoto incluye corchetes de `URL.hostname` en Node y "urllib no normaliza 2130706433: si ipaddress falla, resolver con getaddrinfo y validar" |

## 2. Bugs
Ninguno bloqueante.

## 3. Observaciones BAJA (no bloqueantes)
- **Prefijos IPv6 con IPv4 incrustada no listados**: `::127.0.0.1` (IPv4-compatible, `::/96`, obsoleto) y `::ffff:0:127.0.0.1` (SIIT, `::ffff:0:0:0/96`) dan `is_global=True` en Python 3.9 y no están en la lista de ejemplo del texto. Ejecutado: en macOS ni Node ni Python llegan a loopback (timeout de conexión), así que no hay explotación demostrada; no verificado en Linux. Sugerencia para una tarea futura: añadir ambos prefijos a la lista de ejemplo o validar también su IPv4 incrustada.
- El arnés de QA sustituyó `ipaddr.js` (no integrado) por `net.BlockList` con los rangos del texto; nota: un `BlockList` con `::ffff:0:0/96` bloquea también toda IPv4 al comprobarla como `ipv4`, por lo que hay que usar listas separadas por familia si alguien lo imita.

## 4. Lección
- `LL-011` (ampliada en este commit con corchetes IPv6 en Node y el camino `getaddrinfo` en Python). Cierre con `task.sh close TASK-033 --lesson LL-011`.

## 5. Conclusión y Veredicto Final

- **Estado**: `APROBADA` → `DONE`.
- **Siguiente paso**: fusión a `main` con `--no-ff` y borrado de la rama por el especialista o el `orchestrator-agent` (QA no fusiona). Scripts de QA: `recipe.js`, `probe.js` y `recipe.py` en `/private/tmp/claude-501/-Users-klismanvizcarra-Desktop-PROYECTOS-SKILL--MAESTRO/93d4f4ac-7cb6-4e0f-9815-84fb011827e5/scratchpad/qa033/`.
