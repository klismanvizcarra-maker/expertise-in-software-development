---
name: seo-web
description: Hace indexables y compartibles las páginas públicas de una app Angular - SSR y prerender con render modes por ruta, title y meta description por página, canonical y hreflang, Open Graph y Twitter cards, datos estructurados JSON-LD, sitemap.xml y robots.txt, y código seguro para el servidor. Usar cuando la app tiene páginas públicas que deben aparecer en buscadores o verse bien al compartirse (landing, precios, blog, catálogo). No usar para zonas privadas tras login, que no se indexan.
---

# SEO y Renderizado en Servidor (SSR)

Una SPA sin SSR entrega HTML vacío a los motores de búsqueda. La regla de oro: **lo público se prerenderiza o se renderiza en servidor; lo privado se ejecuta en el cliente**. Verificado con Angular 22 (`@angular/ssr`).

## Protocolo

1. **Diagnóstico y rutas**: clasifica cada ruta de la aplicación en pública (landing, precios, blog, catálogo) o privada (dashboard, checkout, cuenta de usuario).
2. **Configuración de SSR**: si no está instalado, ejecuta `npx ng add @angular/ssr` en la app web. Configura los modos de renderizado por ruta en `app.routes.server.ts`.
3. **Servicio SEO centralizado**: implementa o actualiza `SeoService` (`core/seo/seo.service.ts`) para inyectar `<title>`, `<meta description>`, Open Graph, Twitter Cards y etiquetas canónicas absolutas en cada vista pública.
4. **Blindaje de SSR**: encapsula accesos al DOM o APIs de navegador con `isPlatformBrowser` o `afterNextRender`.
5. **Indexación y descubrimiento**: actualiza `robots.txt` y `sitemap.xml` asegurando exclusión de rutas protegidas.
6. **Verificación y métricas**: compila el proyecto, prueba la salida HTML de las rutas SSR y ejecuta la auditoría de Lighthouse SEO.

---

## 1. Modos de Render por Ruta (`app.routes.server.ts`)
El valor generado por defecto (`'**' → Prerender`) **prerenderiza también las rutas privadas**: configúralo explícitamente:
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
Las rutas `Prerender` con parámetros dinámicos exigen implementar `getPrerenderParams` devolviendo la lista de slugs válidos.

## 2. Metadatos y Marcado Estructurado
Centraliza en `SeoService` y llama al construirse cada componente de página pública:
- `Title.setTitle('Precios | MiApp')` — único por página, ≤ 60 caracteres.
- `Meta.updateTag({ name: 'description', content })` — entre 120 y 160 caracteres.
- **Open Graph y Twitter**: `og:title`, `og:description`, `og:image` (1200×630, URL absoluta), `og:url`, `twitter:card = summary_large_image`.
- **Canónicas**: `<link rel="canonical">` con URL absoluta; en apps multilingües, canonical **por idioma** + `<link rel="alternate" hreflang="es|en|x-default">` (ver `i18n`).
- **JSON-LD**: `<script type="application/ld+json">` para `Organization`, `Product`, `Article` o `BreadcrumbList` según corresponda.
- **Rutas privadas**: `<meta name="robots" content="noindex, nofollow">`.

## 3. Código Seguro para el Servidor
- Prohibido el uso directo de `window`, `document`, `localStorage` o `navigator` en constructores o inicializadores que corran en SSR. Emplea `inject(DOCUMENT)` para el DOM y `afterNextRender(() => …)` para código exclusivo del navegador.
- Las peticiones HTTP con `HttpClient` durante el render se serializan y transfieren al cliente mediante la caché de hidratación integrada; no las dupliques manualmente.

## 4. sitemap.xml y robots.txt
- `public/robots.txt`:
  ```text
  User-agent: *
  Allow: /
  Disallow: /app/
  Disallow: /api/
  Sitemap: https://<dominio>/sitemap.xml
  ```
- `sitemap.xml`: estático en `public/` para páginas fijas, o generado dinámicamente en build para contenidos dinámicos (blog, catálogo). Solo incluye URLs canónicas con respuesta 200.

## 5. Seguridad en Despliegue (SSRF y Hosts Permitidos)
- **Hosts permitidos obligatorios**: el servidor SSR debe responder **400 Bad Request** ante cabeceras `Host` no reconocidas. Configura los dominios en `angular.json` (`build.options.security.allowedHosts`) o vía `NG_ALLOWED_HOSTS`.

## Verificación de Salida
```bash
npm run build -w @app/web
grep -oE '<title>[^<]*</title>|<meta name="description"[^>]*>|<link rel="canonical"[^>]*>' dist/web/browser/index.html
```

## Checklist antes de `task.sh handoff`
- [ ] HTML prerenderizado contiene `<title>`, descripción, canonical absoluto y etiqueta `<h1>` con contenido real.
- [ ] Las rutas privadas (`/app/**`) tienen `renderMode: RenderMode.Client` y no aparecen en `prerendered-routes.json`.
- [ ] Código seguro para SSR: sin llamadas a `window`, `document` o `localStorage` sin protección de plataforma.
- [ ] `robots.txt` y `sitemap.xml` actualizados sin exponer endpoints internos o privados.
- [ ] Puntuación de Lighthouse SEO ≥ 95 en las páginas públicas.
- [ ] Hosts permitidos configurados para protección SSRF.

## Prohibido
- Acceder a APIs del navegador (`window`, `localStorage`, `sessionStorage`, `document`) en el ciclo de vida de SSR sin comprobación de plataforma.
- Dejar rutas privadas tras autenticación bajo el modo `Prerender`.
- Usar URLs relativas en etiquetas canónicas o metadatos de Open Graph (deben ser URLs absolutas completas con protocolo).
- Permitir renderizado SSR con cabecera `Host` arbitraria sin validar.
