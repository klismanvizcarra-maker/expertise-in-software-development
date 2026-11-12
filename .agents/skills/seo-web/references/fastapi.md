# SEO y SSR — FastAPI + PostgreSQL

Receta de referencia para `stack-fastapi-postgres`. Según sirva solo API JSON o también HTML SSR (p. ej. Jinja2), las prioridades difieren:

## 1. Backend API puro (SPA o frontend separado)

- Añade `X-Robots-Tag: noindex, nofollow` en las respuestas de `/api/**` mediante middleware para evitar que endpoints JSON o OpenAPI aparezcan indexados en buscadores.
- En producción desactiva esquema y UIs automáticas (`docs_url=None, redoc_url=None, openapi_url=None` cuando `settings.env == "production"`, salvo documentación pública intencional).
- Mantén `TrustedHostMiddleware` (`from fastapi.middleware.trustedhost import TrustedHostMiddleware`) configurado con la lista cerrada de dominios reales (`allowed_hosts=settings.allowed_hosts`) para rechazar cabeceras `Host` arbitrarias (`400 Invalid host header`).

## 2. FastAPI sirviendo páginas públicas HTML (Jinja2)

- Renderiza en servidor (`HTMLResponse` / `Jinja2Templates`) las rutas públicas con `<title>`, `<meta name="description">`, `<link rel="canonical">` absoluto, Open Graph y JSON-LD (`|tojson` seguro dentro de `<script type="application/ld+json">`).
- Sirve `/robots.txt` (`PlainTextResponse`) excluyendo `/api/` y zonas autenticadas, y `/sitemap.xml` (`Response(media_type="application/xml")`) consultando solo registros publicados con `last_modified`.
- Asegúrate de que `autoescape=True` esté activo en `Jinja2Templates` para evitar XSS al reflejar títulos o descripciones desde base de datos.
