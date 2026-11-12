# Veredicto de QA: TASK-033

- **Tarea**: `TASK-033`
- **Fecha**: 2026-11-11
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `docs-architecture-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `1/3` tras la reapertura (revisión acotada con contexto limpio del commit `b63762c`; el historial previo llegó a 3/3 por BUG-TASK-033-6)

---

## 1. Criterios de Aceptación y Controles

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| Skills con referencias, Checklist y Prohibido; AGENTS.md §2.7; casos de activación | ✅ | Sin cambios en esta iteración (`git diff HEAD~1 --stat`); dados por buenos en el veredicto anterior |
| `test-skills.sh` | ✅ | Ejecutado: 32 skills auditadas sin errores |
| `lint_descriptions.py` | ✅ | Ejecutado: "Sin problemas" |
| `test-scripts.sh` | ✅ | Ejecutado: 239 OK, 0 fallidas |
| `validate-state.sh` | ✅ | Ejecutado: 0 advertencias |
| Escaneo de secretos | ✅ | Ejecutado `scan-secrets.sh --branch`: sin hallazgos |
| BUG-1 a BUG-5 | ✅ | El diff de `b63762c` solo toca la sección SSRF, LL-011 y estado; nada reintroduce la vía "no alcanzable → ADR" (grep `alcanzable\|no aplica` en la skill: solo la prohibición en `checklist.md:58`). Rutas de salud y rate limit intactos (leído) |
| BUG-6: IPv4 literal en Node | ✅ | Ejecutado Node 24.21 con `http.Agent({ lookup })` + validación del literal tras `new URL()`: `127.0.0.1`, `2130706433`, `0177.0.0.1`, `0x7f.1`, `169.254.169.254` bloqueadas antes de conectar (`lookupCalls=0`, confirma que `lookup` no se ejecuta) |
| BUG-6: nombres con `lookup` y `{ all: true }` | ✅ | Ejecutado: `localhost` bloqueado por el `lookup` propio (1 llamada) |
| BUG-6: redirección a IP literal seguida a mano | ✅ (IPv4) / ❌ (IPv6) | Ejecutado: `Location: http://127.0.0.1:<p>/` bloqueada; `Location: http://[::1]:<p>/` pasa (200) si el literal se comprueba con `net.isIP(u.hostname)` |
| IPv6 literal en Node (`[::1]`, `[::ffff:127.0.0.1]`) | ❌ MEDIA | BUG-TASK-033-7 |
| Python: nota sobre `ipaddress` y formas decimales | ❌ MEDIA (texto inexacto) | BUG-TASK-033-7 (parte Python) |
| Python: transporte con `server_hostname`, nunca `verify=False`; `is_global` + `not is_multicast` + IPv4 incrustada | ✅ | Leído; afirmaciones ya verificadas por ejecución en el veredicto anterior |
| LL-011 recoge el hueco de la IP literal | ✅ | Antídoto: "un gancho de DNS (lookup) no ve las URLs con IP literal: validar tambien la IP literal tras normalizar la URL"; `task.sh brain search rebinding` y `brain search SSRF` la encuentran (ejecutado) |

## 2. Bugs

### BUG-TASK-033-7 (MEDIA, seguridad) — La receta del literal falla con IPv6 en Node y la nota de Python es inexacta
- **Observado** (`checklist.md:42`): "pásala por el parser de URL estándar (`new URL()` en Node, `urllib.parse` más `ipaddress` en Python) y, si el host es una IP literal, valídala directamente […] `ipaddress` de Python, en cambio, rechaza esas formas, así que normaliza con el parser de URL antes."
- **Node (ejecutado, Node 24.21)**: `new URL('http://[::1]/').hostname` es `"[::1]"` (con corchetes) y `net.isIP('[::1]')` devuelve `0`. La forma directa de aplicar la receta (`net.isIP(u.hostname)`) no reconoce el literal IPv6, lo trata como nombre, y como `net.connect` recibe `::1` (sin corchetes) tampoco llama a `lookup`. Resultado: `http://[::1]:<p>/` → 200 y `http://[::ffff:127.0.0.1]:<p>/` (hostname `[::ffff:7f00:1]`) → 200, `lookupCalls=0`; igual con una redirección a `http://[::1]/`. Quitando los corchetes antes de `net.isIP` las tres quedan bloqueadas. Es la misma clase de hueco que BUG-6 (el literal se salta los dos controles), ahora en IPv6.
- **Python (ejecutado, Python 3.9.6)**: `urllib.parse.urlsplit('http://2130706433/').hostname` es `'2130706433'`; el parser de URL de Python **no** normaliza `2130706433`, `0177.0.0.1` ni `0x7f.1`, así que "normaliza con el parser de URL antes" no es cierto en Python. Lo que sí las convierte es `getaddrinfo` (`2130706433` → `127.0.0.1`, `0x7f.1` → `127.0.0.1`; en macOS `0177.0.0.1` → `177.0.0.1`, distinto de Node, que da `127.0.0.1`). No abre un hueco si se valida la IP que devuelve `getaddrinfo` y se conecta a ella, pero el texto induce a buscar una normalización que no existe. En Python los corchetes sí se quitan (`urlsplit('http://[::1]/').hostname == '::1'`).
- **Corrección recomendada** (dos frases en la viñeta "Primero, la URL ya normalizada"):
  - Node: "`URL.hostname` conserva los corchetes de IPv6 (`[::1]`): quítalos antes de `net.isIP` o la IPv6 literal se salta la validación."
  - Python: "`urllib.parse` no normaliza formas como `2130706433`: si `ipaddress.ip_address` falla, trata el host como nombre, resuélvelo con `getaddrinfo`, valida las IPs resultantes y conecta a ellas; nunca decidas por el texto."
  - Opcional: en `SKILL.md` paso 6, añadir "IP literal validada tras normalizar la URL" al resumen de SSRF, que hoy solo menciona la IP resuelta.

## 3. Observaciones BAJA (no bloqueantes)
- El handoff afirma "`[::1]` rechazada" en Node 24.21; solo es cierto si el especialista quitó los corchetes, algo que la receta no dice. Conviene que los comandos de verificación del handoff incluyan el script usado.

## 4. Lección
- No se cierra. Al cerrar: ampliar LL-011 (o LL nueva) con "probar cada receta con las variantes de formato de la entrada (IPv6 entre corchetes, formas decimales) en cada lenguaje; el parser de URL de Node y el de Python no devuelven lo mismo".

## 5. Conclusión y Veredicto Final

- **Estado**: `RECHAZADA` → `IN_PROGRESS` (1/3).
- **Siguiente paso**: el especialista retoma con `task.sh start TASK-033` y aplica las dos frases de BUG-TASK-033-7. Scripts de reproducción de QA: `recipe.js` y `probe.js` en el scratchpad de la sesión de QA (se pueden reescribir: servidor en `::`, `http.Agent({ lookup })`, validación del literal con y sin quitar corchetes).
