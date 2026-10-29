# Preferencias de Ingeniería del Desarrollador (Developer Preferences)

> **Propósito**: Directrices explícitas sobre cómo le gusta trabajar al desarrollador humano para que el agente se adapte a su estilo sin necesidad de recordárselo en cada conversación.

---

## 1. Estilo de Código y Estructura
- **Modularidad**: Preferir archivos pequeños y enfocados (menos de 200 líneas preferiblemente).
- **Tipado Fuerte**: Usar TypeScript de forma estricta (`strict: true`), evitando `any`. Usar `unknown` con guardas de tipo si el dato es incierto.
- **Funciones Puras**: Aislar la lógica de cálculo en funciones puras fácilmente testeables sin efectos secundarios.

---

## 2. Experiencia de Usuario (UI/UX)
- **Feedback Inmediato**: Toda acción asíncrona debe reflejar visualmente su estado: botón con estado de carga o esqueleto en la vista.
- **Manejo Amigable de Errores**: En lugar de códigos de error crudos, mostrar mensajes claros y orientados a la solución para el usuario.
- **Diseño Limpio**: Respetar siempre la paleta de colores y el sistema de espaciado estándar.

---

## 3. Pruebas y Validación
- **Pruebas Automatizadas**: Todo nuevo servicio o endpoint crítico debe incluir al menos una prueba unitaria o de integración.
- **Validación Temprana**: Rechazar entradas inválidas en la frontera de la aplicación (en el controlador o middleware) antes de tocar la base de datos.
