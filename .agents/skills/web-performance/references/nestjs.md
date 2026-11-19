# Rendimiento de APIs — NestJS + Prisma / PostgreSQL

Receta de referencia para `stack-nestjs-postgres`. Explica técnicas para reducir la latencia p95, resolver problemas de consultas N+1 con Prisma, implementar compresión, interceptores de caché HTTP y pools de conexión de base de datos.

## 1. Medición de Latencia y Profiling

```bash
# Prueba de carga de latencia p95 con autocannon
npx autocannon -c 50 -d 10 -p 10 http://localhost:3000/api/users
```

## 2. Optimización de Base de Datos y Prisma

- **Prevención de N+1**:
  Usa `include` o `select` específicos con relaciones necesarias, evitando consultar en bucles:
  ```ts
  // Bien: 1 sola consulta o join optimizado
  const users = await this.prisma.user.findMany({
    take: 20,
    select: {
      id: true,
      name: true,
      posts: { select: { id: true, title: true } },
    },
  });
  ```

- **Paginación eficiente por cursor**:
  Evita `skip` altos en tablas grandes; usa `cursor` basado en clave primaria o índice único indexado:
  ```ts
  const items = await this.prisma.item.findMany({
    take: limit,
    skip: cursor ? 1 : 0,
    cursor: cursor ? { id: cursor } : undefined,
    orderBy: { id: 'asc' },
  });
  ```

- **Pool de Conexiones**:
  Ajusta el tamaño del pool en `DATABASE_URL` (`?connection_limit=20&pool_timeout=10`) para prevenir saturación de conexiones bajo concurrencia.

## 3. Caché y Middleware en NestJS

- **Compresión Global (`src/main.ts`)**:
  ```ts
  import * as compression from 'compression';
  app.use(compression());
  ```

- **Interceptor de Caché en Memoria (`CacheInterceptor`)**:
  Para datos de solo lectura de baja volatilidad (ej. catálogos, listas de precios):
  ```ts
  @UseInterceptors(CacheInterceptor)
  @CacheTTL(300) // 5 minutos
  @Get('plans')
  getPublicPlans() {
    return this.billingService.getPlans();
  }
  ```
