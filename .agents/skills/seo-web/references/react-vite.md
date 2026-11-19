# SEO y Prerender — React 19 + Vite + Node

Receta de referencia para `stack-react-vite-node`. Al ser una aplicación Single Page Application (SPA), el indexado requiere gestión del `<head>` con `react-helmet-async`, prerendering estático en build time o un servidor intermedio que sirva metadatos y HTML inicial a crawlers.

## 1. Gestión de Metadatos con `react-helmet-async` (`client/src/`)

```tsx
// client/src/pages/BlogPost.tsx
import { Helmet } from 'react-helmet-async';

interface PostProps {
  post: {
    title: string;
    summary: string;
    slug: string;
    coverUrl: string;
  };
}

export function BlogPost({ post }: PostProps) {
  const canonicalUrl = `https://example.com/blog/${post.slug}`;

  return (
    <>
      <Helmet>
        <title>{post.title} | MiApp</title>
        <meta name="description" content={post.summary} />
        <link rel="canonical" href={canonicalUrl} />
        <meta property="og:title" content={post.title} />
        <meta property="og:description" content={post.summary} />
        <meta property="og:image" content={post.coverUrl} />
        <meta property="og:url" content={canonicalUrl} />
        <meta name="twitter:card" content="summary_large_image" />
        <script type="application/ld+json">
          {JSON.stringify({
            '@context': 'https://schema.org',
            '@type': 'Article',
            headline: post.title,
            description: post.summary,
            image: post.coverUrl,
          })}
        </script>
      </Helmet>
      <article>
        <h1>{post.title}</h1>
        <p>{post.summary}</p>
      </article>
    </>
  );
}
```

## 2. Archivos Estáticos Públicos (`client/public/`)

- `client/public/robots.txt`:
  ```txt
  User-agent: *
  Disallow: /api/
  Disallow: /app/
  Disallow: /settings/

  Sitemap: https://example.com/sitemap.xml
  ```

## 3. Manejo en Servidor Express (`server/src/`)

Para rutas de API y zonas privadas en Node/Express, añade cabeceras anti-indexación:

```ts
// server/src/middlewares/noindex.middleware.ts
import { Request, Response, NextFunction } from 'express';

export function noIndexMiddleware(req: Request, res: Response, next: NextFunction) {
  res.setHeader('X-Robots-Tag', 'noindex, nofollow');
  next();
}
```
Aplica este middleware a todos los endpoints en `/api/**` para que las respuestas JSON no se indexen en Googlebot.
