# Rendimiento Web — React 19 + Vite + Node

Receta de referencia para `stack-react-vite-node`. Se centra en división de código (code splitting) con Vite, gestión de estado y peticiones eficientes con TanStack Query, optimización de bundles y compresión en Express.

## 1. Medición Base

```bash
# Medición de bundle con rollup-plugin-visualizer en client/
npm run build -- --analyze

# Auditoría Lighthouse
npx lighthouse http://localhost:5173/ --only-categories=performance
```

## 2. Optimización Frontend (Vite + React 19)

- **División de rutas con `React.lazy` y `<Suspense>`**:
  Separa cada vista principal en un chunk independiente:
  ```tsx
  import { lazy, Suspense } from 'react';
  import { Routes, Route } from 'react-router-dom';

  const Dashboard = lazy(() => import('./pages/Dashboard'));
  const Settings = lazy(() => import('./pages/Settings'));

  export function AppRoutes() {
    return (
      <Suspense fallback={<div className="spinner" />}>
        <Routes>
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/settings" element={<Settings />} />
        </Routes>
      </Suspense>
    );
  }
  ```

- **Caché y deduplicación con TanStack Query**:
  Configura `staleTime` global para evitar peticiones redundantes al navegar entre pestañas:
  ```ts
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 1000 * 60 * 5, // 5 minutos de validez en memoria
        gcTime: 1000 * 60 * 30, // 30 minutos de retención
        refetchOnWindowFocus: false,
      },
    },
  });
  ```

- **Optimización de Vite (`client/vite.config.ts`)**:
  Configura `manualChunks` para aislar librerías de gran tamaño (`vendor` chunking) y activa minificación terser o esbuild.

## 3. Optimización en Servidor Express (`server/`)

- **Compresión HTTP**:
  Habilita compresión Gzip o Brotli mediante `compression`:
  ```ts
  import compression from 'compression';
  app.use(compression());
  ```

- **Caché de estáticos**:
  En producción, sirve el build de Vite con cabeceras `Cache-Control: public, max-age=31536000, immutable` para archivos con hash y `no-cache` para `index.html`.
