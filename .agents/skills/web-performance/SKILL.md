---
name: web-performance
description: Mide y mejora el rendimiento de apps web Angular + Express - Core Web Vitals (LCP, INP, CLS), presupuestos de bundle, análisis del bundle, carga diferida con @defer, imágenes optimizadas con NgOptimizedImage, fuentes, caché HTTP, compresión, latencia de la API y consultas lentas, con Lighthouse CI y métricas de campo. Usar cuando una página o endpoint es lento, se exceden presupuestos de build, antes de un lanzamiento o al auditar rendimiento. No usar para optimizar sin una medición previa. No usar para logs, métricas o alertas de producción (observability).
---

# Rendimiento Web

**Medir → cambiar una cosa → volver a medir.** Ninguna optimización se entrega sin el número de antes y el de después.

## Objetivos (percentil 75, móvil)

| Métrica | Bueno | Qué la empeora |
| :--- | :--- | :--- |
| **LCP** | ≤ 2,5 s | Imagen principal tardía, JS que bloquea, sin SSR en páginas públicas |
| **INP** | ≤ 200 ms | Trabajo largo en el hilo principal tras una interacción |
| **CLS** | ≤ 0,1 | Imágenes sin dimensiones, contenido que se inserta encima, fuentes que cambian de tamaño |
| **API p95** | ≤ 300 ms | Consultas sin índice, N+1, respuestas sin paginar |
| **JS inicial** | ≤ 500 kB (error a 1 MB, valores por defecto de Angular) | Dependencias pesadas en rutas no diferidas |

## Protocolo
1. **Medir** la línea base:
   ```bash
   npx lighthouse http://localhost:4000/ --only-categories=performance --output=json --output-path=./lh-antes.json   # móvil por defecto (los objetivos son móviles)
   npm run build -w @app/web -- --stats-json     # genera dist/web/browser-stats.json
   ```
   Abre `browser-stats.json` en el analizador de esbuild (`https://esbuild.github.io/analyze/`) para ver qué ocupa el bundle.
2. **Identificar** el cuello de botella con la métrica que falla (tabla de arriba); no optimices lo que ya está en verde.
3. **Aplicar** la técnica correspondiente (abajo), una a la vez.
4. **Repetir la medición** y anotar antes/después en el handoff.

## Técnicas — Frontend (Angular 22)
- **Rutas lazy** (`loadComponent` / `loadChildren`) para todo lo que no sea la primera pantalla.
- **`@defer`** para bloques pesados bajo el pliegue: `@defer (on viewport) { <app-chart /> } @placeholder { <app-skeleton /> }`.
- **Imágenes con `NgOptimizedImage`**: `ngSrc` + `width`/`height` siempre (evita CLS). En la imagen LCP añade `priority`: genera `fetchpriority="high"`, carga inmediata y el `<link rel="preload">` en el HTML prerenderizado. Formatos WebP/AVIF.
- **Fuentes**: autoalojadas en `public/`, `font-display: swap`, solo los pesos usados, *preload* de la principal.
- **Dependencias**: antes de añadir una librería, comprueba su peso; reemplaza utilidades enormes por funciones nativas o importaciones puntuales.
- **SSR/prerender** en páginas públicas (skill `seo-web`): mejora LCP en primera visita.
- **INP**: trocea el trabajo pesado, mueve cálculos grandes a un Web Worker y evita `effect()` que recalculan en cascada.

## Técnicas — Backend y Red
- **Compresión** gzip/brotli en el proxy inverso (o `compression` en Express si no hay proxy).
- **Caché HTTP**: estáticos con hash `Cache-Control: public, max-age=31536000, immutable`; HTML y respuestas de API privadas `no-store` o `private, no-cache`.
- **API**: paginación obligatoria, columnas explícitas, consultas relacionales de Drizzle en lugar de bucles con consultas (N+1), índices revisados con `EXPLAIN (ANALYZE, BUFFERS)`.
- **Medición de latencia**: `pino-http` registra `responseTime`; vigila el p95 por ruta.

## Monitorización Continua
- **Lighthouse CI** en el pipeline (`@lhci/cli`) con aserciones sobre LCP, CLS y peso total, apuntando a las páginas públicas clave.
- **Datos de campo**: la librería `web-vitals` (`onLCP`, `onINP`, `onCLS`) enviando a la analítica del proyecto; los datos de laboratorio no sustituyen a los de usuarios reales.
- **Presupuestos** en `angular.json` → `configurations.production.budgets`: endurécelos cuando el proyecto esté por debajo, nunca los relajes para que pase el build sin un ADR.

## Checklist antes de `task.sh handoff`
- [ ] Medición antes/después adjunta (Lighthouse o tiempos de API).
- [ ] Build dentro de presupuesto sin warnings nuevos.
- [ ] Imagen LCP con `priority`; todas las imágenes con dimensiones.
- [ ] Sin regresiones funcionales (tests y E2E en verde).

## Prohibido
- Entregar una optimización sin mediciones numéricas verificadas de antes y después.
- Relajar los presupuestos de bundle en configuraciones de build para ocultar excesos de peso sin un ADR aprobado.
- Sacrificar accesibilidad, tests funcionales o cobertura de pruebas para ganar microsegundos.
- Emplear librerías pesadas para operaciones triviales que puedan resolverse de forma nativa en la plataforma.
