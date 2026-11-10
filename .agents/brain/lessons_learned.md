# Lecciones Aprendidas y Antipatrones (Lessons Learned)

> **Propósito**: Registro categorizado de bugs complejos superados, trampas de dependencias y soluciones probadas para que ningún agente repita errores del pasado.
> **Comando de registro rápido**: `./.agents/scripts/task.sh learn "<problema: solución>" [categoría]`

---

## 1. Registro de Incidentes Categorizados

| ID | Fecha | Categoría | Problema Encontrado | Causa Raíz | Solución Aplicada (Antídoto) |
| :---: | :---: | :---: | :--- | :--- | :--- |
| `LL-001` | 2026-10-29 | `[SCRIPTS]` | awk en macOS/BSD no reconoce la secuencia de escape `\s` para espacios en blanco | `\s` es una extensión de GNU awk; el awk BSD de macOS lo interpreta literalmente como el carácter 's' | Usar clases POSIX `[[:space:]]` o conjuntos explícitos `[ \t]` en scripts para compatibilidad portátil entre macOS y Linux |
| `LL-002` | 2026-10-29 | `[GIT]` | `git diff -S` omitía commits donde el recuento total de apariciones de la cadena no cambiaba | `-S` (pickaxe) detecta únicamente adiciones o eliminaciones netas en el conteo de ocurrencias exactas de una cadena, no sustituciones o regex | Usar `-G` para evaluar expresiones regulares o recorrer los diffs individuales de cada commit con `git log -p -U0 merge-base..HEAD` |
| `LL-003` | 2026-10-29 | `[DEVOPS]` | `task.sh start` generaba slugs de rama con apóstrofes o guiones (`auditor-ia`) ante títulos con tildes en macOS | `iconv -t ascii//TRANSLIT` en macOS BSD translitera tildes agregando apóstrofes (`'i`) en lugar de letras planas | Normalizar vía `python3 unicodedata.normalize('NFKD')` o, sin python3, sustituciones explícitas `sed -e 's/á/a/g' ...` (nunca `y///`, que falla en locale C: ver LL-007) |
| `LL-004` | 2026-10-29 | `[SECURITY]` | scan-secrets no revisaba archivos con tildes, comillas o barras invertidas en el nombre (configuración.ts salía limpio con una clave dentro) | Con core.quotePath activo git devuelve las rutas no ASCII entre comillas y con escapes octales; core.quotePath=false solo arregla los no ASCII, porque git sigue entrecomillando rutas con comilla doble o barra invertida; [ -f ] y git diff -- con esa ruta no encuentran el archivo | En scripts que leen rutas de git usar siempre salida -z (git diff --name-only -z, ls-files -z) con while IFS= read -r -d ''; como mínimo git -c core.quotePath=false; añadir un test con un nombre no ASCII |
| `LL-005` | 2026-10-29 | `[SECURITY]` | Un secreto commiteado en la rama y borrado en un commit posterior pasaba el escáner de QA | El escáner comparaba solo el merge-base con el árbol de trabajo (diff neto), y el secreto sigue en el historial y se publica con push o merge sin squash | Revisar las líneas añadidas de cada commit de la rama con git log -p -U0 merge-base..HEAD; si aparece, rotar la clave y reescribir el historial antes de publicar |
| `LL-006` | 2026-11-10 | `[DEVOPS]` | sed: el & en el reemplazo es el texto coincidente | En init-project.sh el reemplazo 'Infraestructura & Despliegue' sin escapar corrompia GLOBAL_STATE.md en las ramas --stack (el & se expande al patron completo), y el patron '[Breve descripcion.*' se comia el backtick de cierre; los tests solo buscaban 2 placeholders y no lo vieron | Escapar como \& en el reemplazo de sed, acotar patrones con [^]]*\] en vez de .* y comprobar en tests la linea resultante completa, no solo la ausencia de placeholders |
| `LL-007` | 2026-11-10 | `[DEVOPS]` | tolower de awk y sed y/// no normalizan tildes en locale C | En macOS con LC_CTYPE=C el tolower de awk BSD no baja letras acentuadas y sed y/// con multibyte falla con transform strings are not the same length; con 2>/dev/null el fallo queda mudo y la comparacion de textos se desactiva | Normalizar con python3 unicodedata (NFKD) antes de comparar, probar siempre con LC_ALL=C y no silenciar stderr de una tuberia cuyo resultado vacio cambia el comportamiento |

---

## 2. Antipatrones Prohibidos en este Proyecto

1. **Extensiones GNU en scripts (`[SCRIPTS]`)**: nada de `\s` en awk, `grep -P`, `sed -i` sin sufijo ni `mapfile`; deben funcionar en macOS (BSD, bash 3.2) y en Ubuntu.
2. **Leer rutas de git línea a línea (`[GIT]`)**: usar siempre `-z` con `read -r -d ''`; la salida por defecto entrecomilla y escapa rutas.
3. **Texto sin escapar en `sed` (`[DEVOPS]`)**: `&` y el delimitador en el reemplazo se escapan; los patrones se acotan (`[^]]*\]`) en vez de usar `.*`.
4. **Silenciar un fallo que cambia el resultado (`[DEVOPS]`)**: no usar `2>/dev/null` en una tubería cuya salida vacía se interpreta como "no hay coincidencias".
5. **Tests que solo comprueban ausencias (`[QA]`)**: verificar la línea resultante completa, y confirmar que el test falla con el código anterior.
6. **Estado de la librería en las plantillas (`[DOCS]`)**: `.agents/templates/` no contiene lecciones, deudas ni preferencias reales.
