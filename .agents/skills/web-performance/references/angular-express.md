# Rendimiento Web — Angular 22 + Express 5 + Drizzle

Receta de referencia para el monorepo `stack-angular-express-postgres`.

## 1. Medición base (antes de tocar código)

```bash
npx lighthouse http://localhost:4000/ --only-categories=performance --output=json --output-path=./lh-antes.json
npm run build -w @app/web -- --stats-json   # analiza dist/web/browser-stats.json en esbuild analyze
```

## 2. Técnicas Frontend (Angular 22)

- **Rutas lazy** (`loadComponent` / `loadChildren`) para todo lo que no forme parte de la primera vista.
- **`@defer`** para bloques pesados bajo el pliegue:
  ```html
  @defer (on viewport) { <app-chart /> } @placeholder { <app-skeleton /> }
  ```
- **Imágenes con `NgOptimizedImage`**: `ngSrc` + `width` + `height` siempre (evita CLS). Añade `priority` únicamente a la imagen LCP (`fetchpriority="high"` + `<link rel="preload">` en SSR). Usa formatos WebP/AVIF.
- **Fuentes**: autoalojadas en `public/`, `font-display: swap`, solo pesos usados y `preload` de la principal.
- **INP**: trocea trabajo pesado, mueve cálculos costosos a Web Workers y evita cascadas de `effect()`.
- **Presupuestos**: ajusta `angular.json` → `configurations.production.budgets` (JS inicial por defecto ≤ 500 kB warning / 1 MB error) al endurecer; nunca los relajes sin ADR.

## 3. Técnicas Backend (Express 5 + Drizzle + PostgreSQL)

- **Compresión**: gzip/brotli en proxy inverso (o middleware `compression` si Express responde directamente).
- **Caché HTTP**: estáticos con hash → `Cache-Control: public, max-age=31536000, immutable`; HTML y API privadas → `no-store` o `private, no-cache`.
- **Base de datos y API**: paginación obligatoria, columnas explícitas, consultas relacionales de Drizzle sin bucles N+1 e índices verificados con `EXPLAIN (ANALYZE, BUFFERS)`.
- **Observabilidad de latencia**: registra `responseTime` con `pino-http` y vigila el p95 por ruta.
