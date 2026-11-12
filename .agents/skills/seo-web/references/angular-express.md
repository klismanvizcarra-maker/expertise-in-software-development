# SEO y SSR — Angular 22 (`@angular/ssr`)

Receta de referencia para apps web Angular con Server-Side Rendering y prerender (`stack-angular-express-postgres`).

## 1. Instalación y Modos de Render (`app.routes.server.ts`)

```bash
cd apps/web && npx ng add @angular/ssr
```

El valor por defecto `'**' → RenderMode.Prerender` prerenderiza también zonas privadas; decláralas explícitamente:

```ts
import { RenderMode, ServerRoute } from '@angular/ssr';

export const serverRoutes: ServerRoute[] = [
  { path: '', renderMode: RenderMode.Prerender },
  { path: 'precios', renderMode: RenderMode.Prerender },
  { path: 'blog/:slug', renderMode: RenderMode.Server },
  { path: 'app/**', renderMode: RenderMode.Client }, // privada (JWT en cliente)
  { path: '**', renderMode: RenderMode.Server },
];
```

Las rutas `Prerender` con parámetros dinámicos deben exportar `getPrerenderParams` con los slugs válidos.

## 2. `SeoService` y Código Seguro en Servidor

- Usa `Title.setTitle(...)`, `Meta.updateTag(...)` y un `<link rel="canonical">` único actualizado en `SeoService` mediante `inject(DOCUMENT)`.
- **Prohibido** usar `window`, `document`, `localStorage` o `navigator` directamente en código que corre durante SSR: emplea `inject(DOCUMENT)`, `isPlatformBrowser(platformId)` o `afterNextRender(() => ...)`.
- Las peticiones con `HttpClient` durante el render reutilizan la caché de hidratación integrada; evita duplicarlas en el arranque cliente.

## 3. Hosts Permitidos y Verificación de Salida

Configura los dominios válidos en `angular.json` (`build.options.security.allowedHosts`) o mediante `NG_ALLOWED_HOSTS` para devolver `400 Bad Request` ante cabeceras `Host` desconocidas (mitigación SSRF/host-header).

```bash
npm run build -w @app/web
grep -oE '<title>[^<]*</title>|<meta name="description"[^>]*>|<link rel="canonical"[^>]*>' dist/web/browser/index.html
```
