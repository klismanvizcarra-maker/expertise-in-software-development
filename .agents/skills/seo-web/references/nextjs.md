# SEO y SSR — Next.js 15 (App Router)

Receta de referencia para Next.js 15 (`stack-nextjs-tailwind-prisma`). Por defecto, los Server Components se renderizan en el servidor y entregan HTML completo a los buscadores.

## 1. `metadataBase` y `generateMetadata` (Next.js 15)

Define `metadataBase` una sola vez en `app/layout.tsx` para garantizar URLs absolutas en Open Graph, Twitter Cards y canónicas:

```ts
import type { Metadata } from 'next';

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? 'https://example.com'),
  title: { default: 'MiApp', template: '%s | MiApp' },
};
```

En rutas dinámicas de Next.js 15 recuerda que `params` es una `Promise`:

```ts
export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const post = await getPublishedPost(slug);
  if (!post) return { title: 'No encontrado', robots: { index: false } };

  return {
    title: post.title,
    description: post.summary,
    alternates: { canonical: `/blog/${slug}` },
    openGraph: { title: post.title, description: post.summary, images: [post.coverUrl] },
  };
}
```

Para rutas privadas (`app/(dashboard)/layout.tsx`), exporta `export const metadata: Metadata = { robots: { index: false, follow: false } }` y verifica la sesión en servidor sin cachear HTML privado (`export const dynamic = 'force-dynamic'`).

## 2. `robots.ts` y `sitemap.ts` nativos

- `app/robots.ts`: devuelve `MetadataRoute.Robots` bloqueando `/app/`, `/dashboard/` y `/api/`, apuntando a `/sitemap.xml`.
- `app/sitemap.ts`: consulta en servidor únicamente URLs públicas indexables con código 200 (nunca borradores ni rutas tras login) y devuelve `MetadataRoute.Sitemap` con `lastModified`.

## 3. Código SSR seguro, JSON-LD y validación de Host

- Mantén el acceso a `window`, `document` o `localStorage` exclusivamente dentro de `'use client'` + `useEffect` (nunca durante el render inicial que corre en servidor ni provocando hydration mismatch).
- Al embeber datos estructurados JSON-LD (`<script type="application/ld+json">`) en Server Components con `dangerouslySetInnerHTML`, escapa siempre `<` con `JSON.stringify(jsonLd).replace(/</g, '\\u003c')` para impedir inyección XSS por cierre anticipado de `</script>`.
- Detrás de proxy inverso, valida orígenes permitidos de Server Actions en `next.config.ts` con `experimental.serverActions.allowedOrigins` (solo hostnames, sin protocolo ni ruta) y `images.remotePatterns`, además de validar `Host` en el proxy.
