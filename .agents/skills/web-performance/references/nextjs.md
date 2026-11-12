# Rendimiento Web — Next.js 15 + Prisma

Receta de referencia para `stack-nextjs-tailwind-prisma`.

## 1. Medición base (antes de tocar código)

```bash
npx lighthouse http://localhost:3000/ --only-categories=performance --output=json --output-path=./lh-antes.json
ANALYZE=true npm run build   # con @next/bundle-analyzer configurado en next.config.ts
```

## 2. Técnicas Frontend y Server Components (Next.js 15)

- **Server Components por defecto**: mantén librerías pesadas (markdown, sanitizadores, SDKs) en el servidor sin directiva `'use client'`; pasa props serializables mínimas a Client Components pequeños en las hojas del árbol.
- **Code splitting**: usa `next/dynamic(() => import('./HeavyChart'), { loading: () => <Skeleton /> })` para componentes cliente pesados o interactivos bajo el pliegue.
- **Imágenes (`next/image`)**: `width`/`height` o `fill` con `sizes` correcto siempre (evita CLS). Aplica `priority` solo a la imagen LCP; configura `images.remotePatterns` de forma estricta.
- **Fuentes (`next/font`)**: carga fuentes desde `next/font/google` o `next/font/local` (auto-hospedadas, sin peticiones bloqueantes ni CLS por cambio de fuente).
- **Streaming**: divide consultas lentas independientes con `<Suspense fallback={<Skeleton />}>` o `loading.tsx` para no bloquear el primer byte del shell público.

## 3. Datos, Caché y Prisma

- **Evita waterfalls**: lanza consultas independientes en paralelo (`Promise.all([...])`) en Server Components y Route Handlers.
- **Proyecciones y N+1**: usa `select` / `include` específicos en Prisma, nunca `findMany()` sin `take` en listados; en relaciones paginadas usa cursor (`cursor` + `take`) y valida planes con `EXPLAIN (ANALYZE, BUFFERS)`.
- **Caché HTTP**: respuestas personalizadas o autenticadas con `no-store` / cookies; estáticos con hash inmutables (`/_next/static/*`); contenido público semi-estático con `revalidate` controlado.
