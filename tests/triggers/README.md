# Batería de Activación de Skills

Comprueba que, ante una petición típica, se carga la skill correcta (y no otra que se le parezca). Se ejecuta cada vez que cambias una `description` o añades una skill.

| Archivo | Para qué |
| :--- | :--- |
| `cases.json` | 92 peticiones con la skill esperada (`expect`), alternativas válidas (`accept`) y prohibidas (`forbid`) |
| `lint_descriptions.py` | Análisis estático gratuito: casos que apuntan a skills inexistentes, skills con menos de dos casos y pares de descripciones demasiado parecidas sin límite explícito |
| `run_claude.py` | Ejecución real contra Claude Code en modo `--print`, solo con herramientas de lectura |

## 1. Análisis estático (siempre, no gasta nada)
```bash
python3 tests/triggers/lint_descriptions.py
```

## 2. Claude Code (automático)
Requisito único: la CLI debe tener sesión iniciada (la de la app de escritorio no se comparte):
```bash
"$HOME/Library/Application Support/Claude/claude-code/<versión>/<id>/claude.app/Contents/MacOS/claude" auth login
```
Después:
```bash
python3 tests/triggers/run_claude.py                     # todos los casos (92 en cases.json)
python3 tests/triggers/run_claude.py --only db-01,be-01  # solo algunos
python3 tests/triggers/run_claude.py --model sonnet      # con otro modelo
```
- Cada caso corre en un proyecto temporal instalado con `init-project.sh` y con herramientas solo de lectura: no modifica nada.
- La sesión se corta en cuanto el modelo empieza a trabajar tras cargar las skills; el límite por caso es `--budget` (0,25 USD por defecto). Al final se muestra el coste aproximado.
- Resultados detallados en `tests/triggers/results/` (ignorado por git).

## 3. Antigravity (manual)
No hay CLI `agy` en esta máquina, así que se prueba desde el IDE:
1. Instala el sistema en un proyecto de prueba con `init-project.sh` y ábrelo en Antigravity.
2. Para cada caso de `cases.json`, abre una **conversación nueva**, pega el `prompt` y anota qué skill indica que ha cargado.
3. Empieza por los casos más delicados: `db-01`, `be-01`, `fe-01`, `ux-01`, `pm-01`, `orch-01`, `qa-02`, `nt-01`, `bug-01`, `seo-01`, `perf-01`, `neg-01`.

Lista para copiar en una hoja (id, prompt y esperado):
```bash
python3 -c "import json;[print(c['id'],'|',c['prompt'],'|',' o '.join(c['expect']) or '(ninguna)') for c in json.load(open('tests/triggers/cases.json'))['cases']]"
```

## Cómo Leer los Fallos
- **Cargó la vecina** (ej. `backend-agent` en vez de `database-architect-agent`): añade a la descripción de la vecina un "No usar para … (skill-correcta)" y refuerza en la correcta las palabras que usa el usuario.
- **No cargó ninguna**: la descripción no menciona cómo lo pide el usuario; añade esos términos a "Usar cuando…".
- **Cargó una en un caso negativo**: la descripción es demasiado amplia; acótala.
- Cambia una descripción a la vez y vuelve a ejecutar solo los casos afectados con `--only`.
