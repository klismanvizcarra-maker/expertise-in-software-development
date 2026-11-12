---
name: web-performance
description: Mide y mejora el rendimiento de aplicaciones web y APIs - Core Web Vitals (LCP, INP, CLS), presupuestos de bundle, carga diferida, optimización de imágenes y fuentes, caché HTTP, compresión, latencia p95 y consultas SQL. Usar cuando una página o endpoint es lento, se exceden presupuestos de build, antes de un lanzamiento o al auditar rendimiento. No usar para optimizar sin una medición previa. No usar para logs, métricas o alertas de producción (observability).
---

# Rendimiento Web y de APIs

**Medir → cambiar una cosa → volver a medir.** Ninguna optimización se entrega sin las cifras de antes y después.

## Recetas por stack
Carga la referencia que corresponda al stack del proyecto (`GLOBAL_STATE.md` §2):
- **Angular + Express + Drizzle**: [references/angular-express.md](references/angular-express.md)
- **Next.js + Prisma**: [references/nextjs.md](references/nextjs.md)
- **FastAPI + SQLAlchemy 2**: [references/fastapi.md](references/fastapi.md)
- **Otro stack**: aplica este protocolo de medición y objetivos registrando la configuración en un ADR (`docs-architecture-agent`).

## Objetivos (percentil 75 móvil / p95 API)

| Métrica | Bueno | Qué la empeora |
| :--- | :--- | :--- |
| **LCP** | ≤ 2,5 s | Imagen principal tardía, JS que bloquea, falta de SSR público |
| **INP** | ≤ 200 ms | Tareas largas en el hilo principal tras interacción |
| **CLS** | ≤ 0,1 | Imágenes sin dimensiones, fuentes sin fallback estable, contenido insertado arriba |
| **API p95** | ≤ 300 ms | Consultas sin índice, bucles N+1, *event loop* bloqueado, falta de paginación |
| **Bundle inicial** | Dentro de presupuesto | Librerías pesadas importadas sin división de rutas/bloques |

## Protocolo

1. **Medir línea base**: ejecuta Lighthouse móvil para Web Vitals / análisis de bundle en frontend y mide p95 + `EXPLAIN (ANALYZE, BUFFERS)` en endpoints/queries lentos.
2. **Identificar el cuello real**: ataca la métrica en rojo; prohíbo optimizar código que ya cumple objetivos.
3. **Aplicar un cambio cada vez**:
   - **Frontend**: code splitting por ruta y bajo el pliegue, imágenes LCP priorizadas y con dimensiones explícitas, fuentes autoalojadas con `swap`, trabajo pesado fuera del hilo principal y eliminación de dependencias redundantes.
   - **Backend y red**: compresión gzip/brotli, `Cache-Control` diferenciado (público inmutable vs privado `no-store`), paginación acotada, columnas explícitas, eliminación de N+1 y operaciones bloqueantes fuera del loop asíncrono.
4. **Volver a medir y documentar**: adjunta números antes/después en el handoff (`task.sh handoff`).
5. **Monitorización continua**: Lighthouse CI (`@lhci/cli`) sobre rutas públicas y métricas de campo (`web-vitals`) + latencia p95 en logs.

## Checklist antes de `task.sh handoff`
- [ ] Medición numérica antes/después documentada (Lighthouse, peso de bundle o p95/SQL).
- [ ] Build y presupuestos dentro de límites sin warnings nuevos ni relajación injustificada.
- [ ] Imagen LCP priorizada (`priority`/`fetchpriority="high"`) y todas las imágenes con dimensiones explícitas.
- [ ] Endpoints afectados paginados, con proyección explícita y sin consultas N+1.
- [ ] Sin regresiones en accesibilidad ni en la suite de pruebas funcional.

## Prohibido
- Entregar una optimización sin mediciones verificadas de antes y después.
- Relajar presupuestos de build en configuración para ocultar excesos sin un ADR aprobado.
- Sacrificar accesibilidad, seguridad o tests para ganar microsegundos.
- Incorporar librerías pesadas para tareas triviales resolubles de forma nativa.
