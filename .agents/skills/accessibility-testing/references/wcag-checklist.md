# Lista de Control WCAG 2.1 Nivel AA

Guía de verificación rápida para auditorías automáticas y manuales de accesibilidad.

---

## 1. Perceptible
- **Contraste de Color (1.4.3)**: Mínimo 4.5:1 para texto normal y 3:1 para texto grande (≥18pt o ≥14pt negrita).
- **Contraste No Textual (1.4.11)**: Mínimo 3:1 para bordes de inputs, iconos interactivos y estados de foco.
- **Alternativas de Texto (1.1.1)**: Imágenes con atributo `alt` descriptivo; imágenes decorativas con `alt=""` y `aria-hidden="true"`.
- **Información y Relaciones (1.3.1)**: Estructura semántica correcta (un solo `<h1>`, orden lógico de `<h2>` a `<h6>`, `<main>`, `<nav>`, `<header>`, `<footer>`).

## 2. Operable
- **Accesible por Teclado (2.1.1)**: Toda acción disponible mediante ratón debe poder ejecutarse con `Tab`, `Shift+Tab`, `Enter` y `Espacio`.
- **Sin Trampas de Foco (2.1.2)**: El foco nunca debe quedar atrapado en un elemento (los modales deben capturar el foco mientras están abiertos y liberarlo con `Escape`).
- **Foco Visible (2.4.7)**: Prohibido `outline: none` sin un estilo alternativo de foco de alto contraste.
- **Área de Toque (2.5.5)**: Elementos interactivos con tamaño mínimo de 44x44px en móviles.

## 3. Comprensible
- **Idioma de la Página (3.1.1)**: Atributo `lang` presente y correcto en la etiqueta `<html>`.
- **Etiquetas e Instrucciones (3.3.2)**: Todo input de formulario debe tener un `<label for="...">` asociado explícitamente o `aria-label`.
- **Identificación de Errores (3.3.1)**: Los errores en formularios se anuncian claramente vinculados con `aria-describedby` y `aria-invalid="true"`.

## 4. Robusto
- **Nombre, Función, Valor (4.1.2)**: Botones interactivos sin texto visible deben tener `aria-label` descriptivo (`<button aria-label="Cerrar modal">`).
