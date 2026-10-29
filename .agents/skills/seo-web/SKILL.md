---
name: seo-web
description: Hace indexables y compartibles las páginas públicas de una app Angular - SSR y prerender con render modes por ruta, title y meta description por página, canonical y hreflang, Open Graph y Twitter cards, datos estructurados JSON-LD, sitemap.xml y robots.txt, y código seguro para el servidor. Usar cuando la app tiene páginas públicas que deben aparecer en buscadores o verse bien al compartirse (landing, precios, blog, catálogo). No usar para zonas privadas tras login, que no se indexan.
---

# SEO para Apps Angular

Una SPA sin SSR entrega HTML vacío a los buscadores. La regla: **lo público se prerenderiza o se renderiza en servidor; lo privado se queda en el cliente**. Verificado con Angular 22 (`@angular/ssr`).

## 1. Activar SSR
```bash
cd apps/web && npx ng add @angular/ssr
```
Crea `src/server.ts` (Express con `AngularNodeAppEngine`), `src/main.server.ts`, `src/app/app.config.server.ts`, `src/app/app.routes.server.ts`, añade `provideClientHydration()` y el script `serve:ssr:web`. El build genera `dist/web/browser` y `dist/web/server` (`node dist/web/server/server.mjs`, puerto 4000).

## 2. Modo de Render por Ruta (`app.routes.server.ts`)
El valor generado (`'**' → Prerender`) **prerenderiza también las rutas privadas**: cámbialo siempre.
```ts
import { RenderMode, ServerRoute } from '@angular/ssr';

export const serverRoutes: ServerRoute[] = [
  { path: '', renderMode: RenderMode.Prerender },          // landing: HTML estático en build
  { path: 'precios', renderMode: RenderMode.Prerender },
  { path: 'blog/:slug', renderMode: RenderMode.Server },   // contenido dinámico público
  { path: 'app/**', renderMode: RenderMode.Client },       // zona privada (JWT en memoria: el servidor no tiene sesión)
  { path: '**', renderMode: RenderMode.Server },
];
```
Las rutas `Prerender` con parámetros necesitan `getPrerenderParams` que devuelva la lista de valores.

## 3. Metadatos por Página
Centraliza en un `SeoService` (`core/seo/seo.service.ts`) que cada página pública llama al construirse:
- `Title.setTitle('Precios | MiApp')` — único por página, ≤ 60 caracteres.
- `Meta.updateTag({ name: 'description', content })` — 120–160 caracteres.
- Open Graph y Twitter: `og:title`, `og:description`, `og:image` (1200×630, URL absoluta), `og:url`, `twitter:card = summary_large_image`.
- `<link rel="canonical">` con URL absoluta (créalo con `inject(DOCUMENT)`); en apps multidioma, canonical **por idioma** + `<link rel="alternate" hreflang="es|en|x-default">`.
- JSON-LD (`<script type="application/ld+json">`) para `Organization`, `Product`, `Article` o `BreadcrumbList` según la página.
- Rutas privadas: `<meta name="robots" content="noindex">`.

## 4. Código Seguro para el Servidor
- Nada de `window`, `document`, `localStorage` ni `navigator` en constructores o servicios que se ejecutan en SSR. Usa `inject(DOCUMENT)` para el DOM y `afterNextRender(() => …)` para lo que solo existe en el navegador.
- Las peticiones `HttpClient` hechas durante el render se transfieren al cliente (caché de transferencia de la hidratación); no las repitas manualmente.
- Un error al renderizar una ruta pública es un bug (QA lo prueba con `curl` sobre el HTML).

## 5. sitemap.xml y robots.txt
- `public/robots.txt`: `Allow: /`, `Disallow: /app/` y la línea `Sitemap: https://<dominio>/sitemap.xml`.
- `sitemap.xml`: estático en `public/` para sitios pequeños; generado en build (script que lee las rutas y los slugs) o servido desde una ruta del `server.ts` si el contenido cambia a diario. Solo URLs canónicas, públicas y con estado 200.

## 6. Despliegue
- Proxy inverso: `/api/*` → servicio `apps/api`; todo lo demás → servidor SSR de `apps/web`. Los estáticos con hash ya salen con `Cache-Control: max-age=1y` desde `server.ts`.
- **Hosts permitidos (obligatorio)**: el servidor SSR responde **400 Bad Request** a cualquier cabecera `Host` no autorizada (protección contra SSRF). Declara los dominios en `angular.json` → `build.options.security.allowedHosts` (ej. `["miapp.com", "www.miapp.com"]`) o con la variable `NG_ALLOWED_HOSTS` en la plataforma. Inclúyelo en la prueba de humo de `/release`.

## Verificación
```bash
npm run build -w @app/web
grep -oE '<title>[^<]*</title>|<meta name="description"[^>]*>|<link rel="canonical"[^>]*>' dist/web/browser/index.html
```
- El HTML prerenderizado contiene `<title>`, descripción, canonical y el `<h1>` con texto real.
- Las rutas privadas no aparecen en `dist/web/prerendered-routes.json`.
- Lighthouse (categoría SEO) ≥ 95 en las páginas públicas; validar el JSON-LD con la prueba de resultados enriquecidos de Google.
