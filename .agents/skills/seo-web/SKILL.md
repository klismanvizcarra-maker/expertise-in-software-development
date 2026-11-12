---
name: seo-web
description: Hace indexables y compartibles las páginas públicas de una aplicación web - SSR y prerender por ruta, title y meta description únicos, canonical y hreflang, Open Graph y Twitter cards, datos estructurados JSON-LD, sitemap.xml, robots.txt y validación segura de host en servidor. Usar cuando la app tiene páginas públicas que deben aparecer en buscadores o verse bien al compartirse (landing, precios, blog, catálogo). No usar para zonas privadas tras login, que no se indexan.
---

# SEO y Renderizado en Servidor (SSR)

Una SPA pura entrega HTML vacío a los rastreadores. Regla de oro: **lo público se prerenderiza o renderiza en servidor con metadatos absolutos; lo privado se protege con `noindex` y validación en servidor.**

## Recetas por stack
Carga la referencia que corresponda al stack del proyecto (`GLOBAL_STATE.md` §2):
- **Angular + Express (`@angular/ssr`)**: [references/angular-express.md](references/angular-express.md)
- **Next.js (App Router)**: [references/nextjs.md](references/nextjs.md)
- **FastAPI (API + Jinja2/TrustedHost)**: [references/fastapi.md](references/fastapi.md)
- **Otro stack**: aplica este protocolo agnóstico y registra los detalles de SSR/metadatos en un ADR (`docs-architecture-agent`).

## Protocolo

1. **Diagnóstico y clasificación de rutas**: separa rutas públicas indexables (landing, precios, blog, catálogo) de rutas privadas tras login (dashboard, checkout, cuenta) y endpoints `/api/`.
2. **Estrategia de renderizado por ruta**: configura prerender o SSR en las rutas públicas y excluye del prerender las privadas (`no-store` / render cliente + `noindex, nofollow`).
3. **Metadatos y marcado estructurado**: garantiza en cada vista pública:
   - `<title>` único (≤ 60 caracteres) y `<meta name="description">` (120–160 caracteres).
   - **Open Graph y Twitter Cards**: `og:title`, `og:description`, `og:image` (1200×630, URL absoluta), `og:url`, `twitter:card = summary_large_image`.
   - **Canónica y multilenguaje**: `<link rel="canonical">` absoluta y, si aplica `i18n`, canónica por idioma + `<link rel="alternate" hreflang="...">`.
   - **JSON-LD**: `<script type="application/ld+json">` (`Organization`, `Product`, `Article` o `BreadcrumbList`) serializado de forma segura.
4. **Código seguro para SSR**: aísla accesos a `window`, `document`, `localStorage` o `navigator` solo en el navegador (o bloque cliente) sin provocar diferencias de hidratación.
5. **Indexación y seguridad Host**: publica `robots.txt` y `sitemap.xml` solo con URLs canónicas `200`, y restringe cabeceras `Host` permitidas en el servidor para mitigar SSRF/host-header injection.
6. **Verificación**: inspecciona el HTML servido sin JS y comprueba Lighthouse SEO ≥ 95 en páginas públicas.

## Checklist antes de `task.sh handoff`
- [ ] El HTML devuelto por el servidor en rutas públicas contiene `<title>`, `<meta name="description">`, canonical absoluto y `<h1>` con contenido real.
- [ ] Rutas privadas y `/api/` quedan marcadas con `noindex, nofollow` y fuera del prerender/sitemap.
- [ ] Sin accesos sin guarda a `window`, `document` o `localStorage` en render de servidor.
- [ ] `robots.txt` y `sitemap.xml` actualizados solo con rutas públicas indexables.
- [ ] Puntuación de Lighthouse SEO ≥ 95 en páginas públicas clave.
- [ ] Validación estricta de `Host` / orígenes permitidos configurada en servidor.

## Prohibido
- Acceder a APIs exclusivas del navegador (`window`, `localStorage`, `document`) durante el render en servidor.
- Prerenderizar rutas privadas tras autenticación o cachear HTML con datos de sesión.
- Usar URLs relativas en etiquetas `<link rel="canonical">` o metadatos Open Graph (`og:image`, `og:url`).
- Aceptar cabeceras `Host` arbitrarias en el servidor SSR sin una lista cerrada de hosts permitidos.
