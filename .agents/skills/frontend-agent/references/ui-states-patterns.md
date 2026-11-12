# Patrones de UI: 4 Estados, Optimistic UI y Formularios

Guía práctica complementaria a `frontend-agent`, agnóstica de framework (React/Next.js, Angular Signals, Vue/Svelte).

## 1. Matriz de 4 Estados por Vista y Componente Asíncrono

| Estado | Implementación mínima obligatoria | Anti-patrón a evitar |
| :--- | :--- | :--- |
| **Loading** | *Skeleton* con ancho/alto reservados iguales al contenido final (`min-height` / `aspect-ratio`) + `aria-busy="true"` | *Spinner* suelto que colapsa a `0 px` y causa *Cumulative Layout Shift* (CLS) al llegar los datos |
| **Empty** | Ilustración/icono decorativo (`aria-hidden="true"`), explicación breve de por qué está vacío y **CTA principal** (o botón "Limpiar filtros" si viene de búsqueda) | Tabla vacía sin headers ni explicación o pantalla en blanco |
| **Success** | Datos formateados con locale (`Intl`), jerarquía visual clara y acciones accesibles | Recalcular totales/precios de negocio en plantillas cuando existen en `domain/` o API |
| **Error / Offline** | Mensaje comprensible para el usuario (mapeado desde `error.code`, sin códigos crudos ni stacks), botón **Reintentar** con foco accesible y conservación de datos ingresados | Pantalla rota permanente, borrar el formulario tras un 500 o mostrar mensajes en inglés/técnicos sin acción |

## 2. Mutaciones, Optimistic UI y Concurrencia

- **Anti doble-envío**: deshabilita el botón de envío e indica estado `saving` (`aria-disabled` + texto/spinner sutil) desde el primer click hasta recibir respuesta o error.
- **Actualización optimista segura** (likes, toggles, reordenamientos, checklists):
  1. Guarda *snapshot* del estado anterior antes de mutar la UI.
  2. Aplica el cambio optimista de forma inmutable en el store/signal.
  3. En `catch`: **revierte al snapshot exacto** y muestra notificación no intrusiva (*toast* `role="status"` / alerta) con opción de reintentar. Nunca apliques optimistic UI sobre pagos ni acciones destructivas irreversibles.
- **Condiciones de carrera en búsquedas/navegación**:
  - Usa `debounce` de 250–400 ms en buscadores reactivos.
  - Cancela peticiones obsoletas (`AbortController` en `fetch`, `switchMap`/`onCleanup` en Angular `effect`/RxJS) para que una respuesta lenta vieja nunca sobrescriba una búsqueda más reciente.

## 3. Formularios, Accesibilidad y Rendimiento Visual

- **Validación y feedback**:
  - Valida en *blur* / cambio sin bloquear el tipeo; conecta cada error al input con `aria-invalid="true"` y `aria-describedby="<id-error>"`.
  - Mapea errores del backend (`422` por campo y código máquina `ERR_*`) directamente al control afectado o a un resumen con `role="alert"` al inicio del formulario.
  - Si el formulario es largo, guarda borrador o avisa antes de salir si hay cambios sin guardar.
- **Checklist rápido antes de `/handoff`**:
  - [ ] Probado en `375 px`, `768 px` y `1280 px` sin scroll horizontal inesperado.
  - [ ] Operable 100 % con `Tab` / `Shift+Tab` / `Enter` / `Escape` (modales atrapan foco y lo devuelven al botón disparador al cerrarse).
  - [ ] Consola y pestaña Red sin errores 404/500 inesperados ni *hydration mismatch* en SSR.

