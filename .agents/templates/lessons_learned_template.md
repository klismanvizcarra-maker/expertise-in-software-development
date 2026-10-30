# Lecciones Aprendidas y Antipatrones (Lessons Learned)

> **Propósito**: Registro categorizado de bugs complejos superados, trampas de dependencias y soluciones probadas para que ningún agente repita errores del pasado.
> **Comando de registro rápido**: `./.agents/scripts/task.sh learn "<problema: solución>" [categoría]`

---

## 1. Registro de Incidentes Categorizados

| ID | Fecha | Categoría | Problema Encontrado | Causa Raíz | Solución Aplicada (Antídoto) |
| :---: | :---: | :---: | :--- | :--- | :--- |

---

## 2. Antipatrones Prohibidos en este Proyecto

1. **Manipulación directa del DOM (`[FRONTEND]`)**: Emplear siempre el estado reactivo del framework.
2. **Consultas SQL sin parametrizar (`[DATABASE]`)**: Prohibida la interpolación directa de variables en cadenas SQL.
3. **Secretos quemados en código (`[SECURITY]`)**: Toda credencial o URL sensible debe inyectarse vía variables `.env`.
4. **Respuestas de error con stack trace interno (`[BACKEND]`)**: Los errores 500 no deben filtrar nombres de tablas ni rutas del sistema operativo.
5. **Estilos y colores quemados en línea (`[UI/UX]`)**: Todo color, radio o sombra debe referenciar los tokens globales de diseño.
