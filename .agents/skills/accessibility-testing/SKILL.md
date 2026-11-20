---
name: accessibility-testing
description: Automatiza auditorías de accesibilidad web bajo el estándar WCAG 2.1 Nivel AA mediante Axe-core y Playwright - valida contraste de color, estructura de encabezados, navegación por teclado, roles ARIA, etiquetas de formularios y áreas de toque táctil, bloqueando regresiones de accesibilidad en CI/CD. Usar al auditar vistas públicas o formularios, al añadir suites de accesibilidad automatizada o para verificar cumplimiento legal de accesibilidad web. No usar para definir la paleta de colores o tokens visuales del sistema de diseño (usar ui-ux-agent) ni para flujos funcionales generales sin foco en accesibilidad (usar e2e-testing).
---

# accessibility-testing — Auditoría Automatizada de Accesibilidad (WCAG 2.1 AA)

La skill técnica `accessibility-testing` blinda las aplicaciones web contra barreras de acceso para personas con discapacidades o que utilizan lectores de pantalla, integrando el motor `@axe-core/playwright` en la suite de pruebas automatizadas.

Para la guía normativa completa consulta [wcag-checklist.md](references/wcag-checklist.md) y para ejemplos de código [playwright-axe.md](references/playwright-axe.md).

---

## Protocolo

1. **Instalación de Dependencias**:
   - Integra `@axe-core/playwright` como dependencia de desarrollo en el proyecto web.

2. **Configuración de Reglas WCAG 2.1 AA**:
   - Configura el escaneo con las etiquetas estándar `['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']`.
   - Excluye componentes de terceros que no estén bajo control del proyecto únicamente documentándolo con justificación explícita.

3. **Auditoría de los Cuatro Principios**:
   - **Perceptible**: Verifica contraste de texto (≥4.5:1), alternativas textuales en imágenes y estructura jerárquica de encabezados (`h1` a `h6`).
   - **Operable**: Prueba navegación exclusivamente con teclado (`Tab`, `Shift+Tab`, `Enter`, `Escape`), orden de foco predecible e indicador de foco visible (sin `outline: none` huérfano).
   - **Comprensible**: Atributo `lang` en `<html>`, etiquetas `<label>` vinculadas a inputs y mensajes de error anunciados vía `aria-describedby`.
   - **Robusto**: Nombres accesibles en botones de iconos (`aria-label`) y roles semánticos (`dialog`, `navigation`, `main`).

4. **Aserciones en Integración Continua**:
   - Incluye assertions que hagan fallar la suite si `violations.length > 0`.
   - Genera reportes con selector CSS, resumen de impacto y enlace a la regla de Deque University.

---

## Checklist

- [ ] Dependencia `@axe-core/playwright` instalada y tipada en la suite de tests.
- [ ] Test canónico de accesibilidad configurado para cada vista o pantalla principal.
- [ ] Cero violaciones detectadas en etiquetas `wcag2aa` y `wcag21aa`.
- [ ] Contraste de color comprobado tanto en tema claro como en tema oscuro si aplica.
- [ ] Navegación por teclado verificada sin trampas de foco en modales ni dropdowns.
- [ ] Todos los botones de sólo iconos tienen `aria-label` descriptivo.

---

## Prohibido

- Prohibido suprimir reglas de Axe-core para silenciar tests fallidos sin aprobación explícita.
- Prohibido usar `outline: none` en CSS sin proveer un reemplazo de foco de alto contraste.
- Prohibido dejar botones interactivos sin texto visible ni atributo `aria-label`.
- Prohibido omitir el atributo `alt` en etiquetas `<img>`.
