# Lecciones Aprendidas y Antipatrones (Lessons Learned)

> **Propósito**: Registro categorizado de bugs complejos superados, trampas de dependencias y soluciones probadas para que ningún agente repita errores del pasado.
> **Comando de registro rápido**: `./.agents/scripts/task.sh learn "<problema: solución>" [categoría]`

---

## 1. Registro de Incidentes Categorizados

| ID | Fecha | Categoría | Problema Encontrado | Causa Raíz | Solución Aplicada (Antídoto) |
| :---: | :---: | :---: | :--- | :--- | :--- |
| `LL-001` | 2026-10-10 | `[DATABASE]` | Bloqueos de concurrencia en SQLite | Modo journal DELETE bloquea lecturas | Configurar `PRAGMA journal_mode = WAL;` y `busy_timeout = 5000` |
| `LL-002` | 2026-10-10 | `[FRONTEND]` | Fugas de memoria en componentes | Suscripciones abiertas sin destruir | Prohibido suscribirse sin `takeUntilDestroyed` o usar Signals puros |
| `LL-003` | 2026-10-10 | `[SECURITY]` | Fuga de detalles internos en errores 500 | Respuestas crudas de base de datos | Middleware centralizado de errores que anonimiza trazas en producción |
| `LL-004` | 2026-10-29 | `[SECURITY]` | scan-secrets no revisaba archivos con tildes, comillas o barras invertidas en el nombre (configuración.ts salía limpio con una clave dentro) | Con core.quotePath activo git devuelve las rutas no ASCII entre comillas y con escapes octales; core.quotePath=false solo arregla los no ASCII, porque git sigue entrecomillando rutas con comilla doble o barra invertida; [ -f ] y git diff -- con esa ruta no encuentran el archivo | En scripts que leen rutas de git usar siempre salida -z (git diff --name-only -z, ls-files -z) con while IFS= read -r -d ''; como mínimo git -c core.quotePath=false; añadir un test con un nombre no ASCII |
| `LL-005` | 2026-10-29 | `[SECURITY]` | Un secreto commiteado en la rama y borrado en un commit posterior pasaba el escáner de QA | El escáner comparaba solo el merge-base con el árbol de trabajo (diff neto), y el secreto sigue en el historial y se publica con push o merge sin squash | Revisar las líneas añadidas de cada commit de la rama con git log -p -U0 merge-base..HEAD; si aparece, rotar la clave y reescribir el historial antes de publicar |

---

## 2. Antipatrones Prohibidos en este Proyecto

1. **Manipulación directa del DOM (`[FRONTEND]`)**: Emplear siempre el estado reactivo del framework.
2. **Consultas SQL sin parametrizar (`[DATABASE]`)**: Prohibida la interpolación directa de variables en cadenas SQL.
3. **Secretos quemados en código (`[SECURITY]`)**: Toda credencial o URL sensible debe inyectarse vía variables `.env`.
4. **Respuestas de error con stack trace interno (`[BACKEND]`)**: Los errores 500 no deben filtrar nombres de tablas ni rutas del sistema operativo.
5. **Estilos y colores quemados en línea (`[UI/UX]`)**: Todo color, radio o sombra debe referenciar los tokens globales de diseño.
