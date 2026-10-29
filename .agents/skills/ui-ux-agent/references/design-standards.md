# Estándares de Diseño de Referencia

Valores por defecto del sistema. Ajústalos por proyecto, pero documenta cualquier cambio en `.agents/brain/preferences.md`.

## Escalas de Tokens

| Familia | Valores |
| :--- | :--- |
| Espaciado | Múltiplos de 4 px: `--space-1: 4px` … `--space-16: 64px` |
| Tipografía | Escala modular de 12 px a 36 px; pesos 400 / 500 / 600 / 700; interlineado ≥ 1.5 en texto de lectura |
| Radios | `--radius-sm: 6px`, `--radius-md: 8px`, `--radius-lg: 12px`, `--radius-full: 9999px` |
| Sombras | Multicapa y suaves, `--shadow-sm` … `--shadow-xl`; preferirlas a bordes oscuros |
| Paleta | Neutros Slate/Zinc, un acento de marca, semánticos Éxito / Advertencia / Peligro / Info |
| Temas | `[data-theme="dark"]` + detección de `prefers-color-scheme` |

## Movimiento

| Uso | Duración | Curva |
| :--- | :--- | :--- |
| Hover, clic, tooltip | 150 ms | `cubic-bezier(0.4, 0, 0.2, 1)` |
| Acordeones, toasts | 250 ms | `cubic-bezier(0.4, 0, 0.2, 1)` |
| Modales, cambio de vista | 300 ms | `cubic-bezier(0.16, 1, 0.3, 1)` (entrada enérgica) |

## Leyes de Usabilidad Aplicadas

- **Fitts**: controles ≥ 44×44 px; acciones destructivas separadas de las cotidianas.
- **Hick**: una sola acción primaria destacada por vista; formularios largos divididos en pasos.
- **Jakob**: convenciones conocidas (logo arriba a la izquierda, perfil/ajustes arriba a la derecha, búsqueda visible, navegación estable).
- **CLS < 0.1**: skeletons con la altura y anchura del contenido final.

## Anatomía de Componentes (`components_template.css`)

- **Botón `.btn`**: variantes `-primary`, `-secondary`, `-ghost`, `-danger`. Hover con leve elevación; active `transform: scale(0.98)`; disabled sin cursor interactivo; spinner integrado que conserva el ancho.
- **Campo `.form-group` / `.input`**: etiqueta visible enlazada (`for`/`id`); foco con anillo `box-shadow`; error `.input-error` + mensaje con `aria-describedby`.
- **Tarjeta `.card`**: superficie con borde `1px solid var(--border-light)`; si es clicable, hover `translateY(-2px)` con sombra media.
- **Modal**: fondo translúcido con `backdrop-filter: blur(8px)`, *focus trap*, cierre con `Escape` y clic en el fondo.
- **Empty state**: icono o ilustración + título + explicación de una línea + botón para crear el primer elemento. Nunca una tabla vacía en blanco.
