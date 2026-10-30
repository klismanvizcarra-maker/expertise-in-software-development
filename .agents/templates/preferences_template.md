# Preferencias del Desarrollador y Convenciones del Proyecto (Preferences)

> **Propósito**: Guía vinculante para todos los agentes sobre estilo de código, estructura y experiencia de usuario.

---

## 1. Convenciones de Código y Arquitectura

- **Límites de Tamaño**: Archivos y funciones concisas (preferiblemente menores a 200 líneas).
- **Tipado Estricto**: TypeScript / tipos estrictos; prohibido el uso indiscriminado de `any`.
- **Estructura de Respuestas**: Formato consistente `{ success: boolean, data?: T, error?: { code, message } }`.
- **Validación en Fronteras**: Esquemas Zod / validación estricta en todo punto de entrada HTTP o mensaje.

---

## 2. Experiencia de Usuario y Diseño

- **Tokens Semánticos**: Uso estricto de variables y tokens de color, espaciado y tipografía; cero valores arbitrarios en línea.
- **Accesibilidad**: Mínimo WCAG 2.1 AA (contrastes, etiquetas accesibles y navegación por teclado).
- **Feedback Inmediato**: Indicadores visuales claros para estados de carga, éxito y error en componentes interactivos.
