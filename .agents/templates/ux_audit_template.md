# Plantilla de Auditoría Heurística de UX (UX Audit Checklist)

- **Pantalla / Módulo**: `[Nombre del componente o vista]`
- **Tarea Vinculada**: `[TASK-XXX]`
- **Auditor**: `[ui-ux-agent | qa-security-agent]`
- **Fecha**: `YYYY-MM-DD`

---

## 1. Evaluación de Leyes de Usabilidad y Psicología UX

| Heurística / Ley | Criterio de Verificación | Estado | Observación |
| :--- | :--- | :---: | :--- |
| **Ley de Fitts** | Botones e inputs con área táctil >= 44x44px en móviles | `[OK / FALLA]` | |
| **Ley de Hick** | Acciones primarias claramente diferenciadas de las secundarias | `[OK / FALLA]` | |
| **Ley de Jakob** | Patrones de navegación convencionales e intuitivos | `[OK / FALLA]` | |
| **Zero Layout Shift (CLS)** | Skeletons con dimensiones exactas para evitar saltos al cargar datos | `[OK / FALLA]` | |

---

## 2. Accesibilidad e Inclusión (WCAG 2.1 AA)

- [ ] **Contraste de Color**: Ratio mínimo de 4.5:1 verificado en texto normal y 3:1 en controles.
- [ ] **Navegación por Teclado**: Todo el flujo se puede operar con `Tab`, `Enter`, `Espacio` y `Escape`.
- [ ] **Indicador de Foco**: Anillo `:focus-visible` claramente perceptible sin alterar el diseño.
- [ ] **Lectores de Pantalla**: Iconos y botones sin texto cuentan con `aria-label` descriptivo.

---

## 3. Estados de Componentes y Resiliencia Visual

- [ ] **Estado Vacío (*Empty State*)**: Ilustración/icono presente con título y botón de acción.
- [ ] **Estado de Carga (*Loading State*)**: Skeletons o botones con spinner integrado que no deforman el ancho.
- [ ] **Estado de Error**: Mensajes comprensibles en línea junto al campo con `aria-describedby`.
- [ ] **Tema Oscuro / Claro**: Sin textos ilegibles o bordes invisibles al alternar temas.

---

## 4. Veredicto de Experiencia de Usuario
- **Resultado**: `[APROBADO PARA QA | RECHAZADO CON OBSERVACIONES]`
- **Notas de Mejora**:
