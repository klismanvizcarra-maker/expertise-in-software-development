# Rendimiento Web — Vue 3 + Nuxt 3

Receta de referencia para `stack-vue-nuxt-postgres`. Enfocada en optimización de Core Web Vitals (LCP, INP, CLS), renderizado diferido, presupuestos de bundle con Vite y consultas Drizzle ORM eficientes.

## 1. Medición Base

```bash
# Auditoría de Lighthouse local
npx lighthouse http://localhost:3000/ --only-categories=performance --output=json --output-path=./lh-report.json

# Análisis visual del bundle con rollup-plugin-visualizer
npx nuxi build --analyze
```

## 2. Optimización Frontend (Nuxt 3 / Vue 3)

- **Carga de imágenes (`@nuxt/image`)**:
  Usa `<NuxtImg>` o `<NuxtPicture>` para entrega automática en formatos modernos (WebP/AVIF).
  Aplica `loading="lazy"` a imágenes bajo el pliegue y `preload` únicamente a la imagen LCP.
  Define siempre `width` y `height` para evitar cambios de diseño (CLS).

- **Componentes diferidos (`Lazy*`)**:
  Aprovecha el prefijo nativo de Nuxt para code-splitting automático:
  ```vue
  <!-- Carga solo cuando sea visible o interactivo -->
  <LazyUserDashboardWidget v-if="showWidget" />
  ```

- **Fuentes auto-hospedadas (`@nuxtjs/google-fonts` o `@nuxt/fonts`)**:
  Evita peticiones bloqueantes de red configurando la descarga local y `font-display: swap`.

## 3. Optimización Backend Nitro y Drizzle

- **Evita waterfalls en endpoints Nitro**:
  Usa `Promise.all` para resolver consultas independientes en paralelo:
  ```ts
  const [profile, recentOrders] = await Promise.all([
    getProfile(userId),
    getRecentOrders(userId),
  ]);
  ```

- **Proyecciones y paginación con Drizzle**:
  Selecciona únicamente las columnas necesarias (`.select({ id: orders.id, amount: orders.amount })`), nunca `select()` completo para listados.
  Aplica paginación con cursor (`where(gt(orders.id, cursor)).limit(20)`).
  Verifica que las consultas utilicen índices adecuados con `EXPLAIN (ANALYZE, BUFFERS)`.

- **Caché de rutas públicas con Nitro**:
  Configura `routeRules` en `nuxt.config.ts`:
  ```ts
  export default defineNuxtConfig({
    routeRules: {
      '/': { prerender: true },
      '/blog/**': { swr: 3600 }, // SWR: 1 hora de caché en CDN
      '/api/**': { cors: true },
    },
  });
  ```
