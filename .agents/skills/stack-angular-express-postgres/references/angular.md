# Angular 22 — Convenciones

## Estructura de `apps/web/src/app`
```text
core/            # Singletons: auth (store, interceptor, guards), http, error handling
shared/ui/       # Componentes de presentación reutilizables (botón, campo, modal, empty-state)
features/<feature>/
├── <feature>.routes.ts       # Rutas lazy de la funcionalidad
├── pages/                    # Componentes contenedores (uno por ruta)
├── components/               # Presentación específica de la funcionalidad
└── data/<feature>.api.ts     # Acceso HTTP tipado con @app/shared
app.config.ts · app.routes.ts · app.ts
```
Nombres de archivo sin sufijo de tipo (convención actual del CLI): `user-card.ts`, `user-card.html`, `user-card.css`, `user-card.spec.ts`.

## Componentes
- Standalone (sin `NgModule`); declara en `imports` solo lo que usa la plantilla.
- **No declares `changeDetection`**: `OnPush` es el valor por defecto en v22. La app es **zoneless** (sin `zone.js`): la vista se actualiza por señales, eventos de plantilla y `async`/`httpResource`. Un cambio en una propiedad normal fuera de esos mecanismos **no** repinta.
- Entradas y salidas con funciones: `input()`, `input.required()`, `output()`, `model()`. Consultas con `viewChild()` / `contentChildren()`.
- Inyección con `inject()`, no con el constructor.
- Plantillas con control de flujo nativo: `@if`, `@for (item of items(); track item.id)`, `@switch`, `@defer` para bloques pesados. Nunca `*ngIf` / `*ngFor`.
- Estilos solo con clases del sistema y `var(--token)`; nada de `style="..."`.

## Estado
- `signal()` para estado local, `computed()` para derivados, `linkedSignal()` para estado que se reinicia cuando cambia su fuente.
- Estado compartido de una funcionalidad: un servicio `@Injectable({ providedIn: 'root' })` con señales privadas (`#items = signal<...>`) expuestas como `asReadonly()` y métodos que las mutan.
- `effect()` solo para sincronizar con el exterior (localStorage, analítica, DOM de terceros); nunca para derivar estado.
- Si usas RxJS: `toSignal()` para consumir y `takeUntilDestroyed()` para cualquier `subscribe` manual.

## Datos HTTP
- **Lecturas**: `httpResource<T>(() => url)` (estable desde v22). Expone `value()`, `isLoading()`, `error()` y `reload()`, que mapean directamente a los 4 estados del PRD:
  ```html
  @if (orders.isLoading()) { <app-skeleton-list /> }
  @else if (orders.error()) { <app-error-state (retry)="orders.reload()" /> }
  @else if (!orders.value()?.length) { <app-empty-state /> }
  @else { @for (o of orders.value(); track o.id) { <app-order-card [order]="o" /> } }
  ```
- **Mutaciones**: `HttpClient` desde `data/<feature>.api.ts`, tipado con los tipos de `@app/shared`; tras mutar, `reload()` del recurso afectado.
- Proveedores en `app.config.ts`: `provideHttpClient(withInterceptors([authInterceptor, errorInterceptor]))`, `provideRouter(routes, withComponentInputBinding())`, `provideBrowserGlobalErrorListeners()`.

## Formularios: Signal Forms (`@angular/forms/signals`, estable en v22)
```ts
import { form, required, email, minLength, submit, FormField } from '@angular/forms/signals';
import { LoginRequest } from '@app/shared';

model = signal<LoginRequest>({ email: '', password: '' });
loginForm = form(this.model, (p) => {
  required(p.email, { message: 'El email es obligatorio' });
  email(p.email, { message: 'Email no válido' });
  minLength(p.password, 8);
});
```
```html
<form (submit)="onSubmit($event)">
  <input id="email" type="email" [formField]="loginForm.email" aria-describedby="email-error" />
  @if (loginForm.email().touched() && loginForm.email().invalid()) {
    <p id="email-error" class="field-error">{{ loginForm.email().errors()[0].message }}</p>
  }
</form>
```
- Importa `FormField` en el componente; envía con `submit(this.loginForm, async () => ...)`.
- Las reglas del formulario reflejan el esquema Zod de `@app/shared`; la API vuelve a validar siempre.
- Formularios reactivos clásicos solo en código existente; no los mezcles con `ngModel` ni con Signal Forms en el mismo formulario.

## Rutas
- Lazy por funcionalidad: `{ path: 'orders', loadChildren: () => import('./features/orders/orders.routes') }`.
- Guards e interceptores **funcionales** (`CanActivateFn`, `HttpInterceptorFn`).
- Parámetros de ruta como `input()` gracias a `withComponentInputBinding()`.

## Tests (Vitest vía `ng test`)
- `npm test -w @app/web` (`ng test --watch=false` en CI). El entorno es `jsdom`.
- Componentes con `TestBed` + `await fixture.whenStable()` (zoneless: no uses `fakeAsync`/`tick` de zone.js).
- HTTP con `provideHttpClientTesting()` y `HttpTestingController`.
- Prueba comportamiento visible (texto, roles, eventos), no detalles internos.
