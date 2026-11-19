# SEO y SSR — Vue 3 + Nuxt 3

Receta de referencia para `stack-vue-nuxt-postgres`. Nuxt 3 realiza renderizado en servidor (SSR) de forma nativa a través del motor Nitro, entregando HTML semántico completo listo para indexación.

## 1. Composable `useSeoMeta` y `useHead`

Aplica metadatos y Open Graph en páginas y layouts utilizando los composables universales de Nuxt:

```vue
<!-- pages/blog/[slug].vue -->
<script setup lang="ts">
const route = useRoute();
const slug = route.params.slug as string;

// Cargar datos en el servidor
const { data: post } = await useFetch(`/api/posts/${slug}`);

if (!post.value) {
  throw createError({ statusCode: 404, statusMessage: 'Post no encontrado' });
}

useSeoMeta({
  title: () => `${post.value?.title} | MiApp`,
  description: () => post.value?.summary,
  ogTitle: () => post.value?.title,
  ogDescription: () => post.value?.summary,
  ogImage: () => post.value?.coverUrl,
  ogType: 'article',
  twitterCard: 'summary_large_image',
});

useHead({
  link: [
    {
      rel: 'canonical',
      href: () => `https://example.com/blog/${slug}`,
    },
  ],
  script: [
    {
      type: 'application/ld+json',
      innerHTML: JSON.stringify({
        '@context': 'https://schema.org',
        '@type': 'BlogPosting',
        headline: post.value?.title,
        description: post.value?.summary,
        image: post.value?.coverUrl,
        datePublished: post.value?.publishedAt,
      }),
    },
  ],
});
</script>

<template>
  <article>
    <h1>{{ post?.title }}</h1>
    <p>{{ post?.content }}</p>
  </article>
</template>
```

## 2. Sitemap y Robots en Nitro (`server/routes/`)

Crea rutas server puras para servir `robots.txt` y `sitemap.xml`:

```ts
// server/routes/robots.txt.ts
export default defineEventHandler((event) => {
  setHeader(event, 'Content-Type', 'text/plain');
  return `User-agent: *
Disallow: /api/
Disallow: /admin/
Disallow: /dashboard/

Sitemap: https://example.com/sitemap.xml`;
});
```

```ts
// server/routes/sitemap.xml.ts
import { db } from '~~/server/utils/db';

export default defineEventHandler(async (event) => {
  setHeader(event, 'Content-Type', 'application/xml');
  // Consultar slugs publicados
  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://example.com/</loc>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>`;
});
```

## 3. Zonas Privadas

En páginas protegidas tras autenticación (`pages/dashboard/**`), desactiva la indexación para prevenir fugas de contenido:

```vue
<!-- pages/dashboard/index.vue -->
<script setup lang="ts">
useSeoMeta({
  robots: 'noindex, nofollow',
});
</script>
```
