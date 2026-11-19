# SEO y Cabeceras Web — NestJS + PostgreSQL

Receta de referencia para `stack-nestjs-postgres`. Al ser un framework de backend API modular, las responsabilidades de SEO se centran en:
1. Protección de endpoints JSON y documentación OpenAPI contra indexación accidental (`X-Robots-Tag: noindex, nofollow`).
2. Validación de dominios permitidos (`Host` validation) para evitar ataques de envenenamiento de caché o cabecera Host.
3. Entrega de `robots.txt` y `sitemap.xml` dinámico si el backend sirve directamente las rutas públicas.

## 1. Interceptor de Cabeceras Anti-Indexación (`src/common/interceptors/noindex.interceptor.ts`)

```ts
import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { Response } from 'express';

@Injectable()
export class NoIndexInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const res = context.switchToHttp().getResponse<Response>();
    res.setHeader('X-Robots-Tag', 'noindex, nofollow');
    return next.handle();
  }
}
```

Aplica este interceptor globalmente en `src/app.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { NoIndexInterceptor } from './common/interceptors/noindex.interceptor';

@Module({
  providers: [
    {
      provide: APP_INTERCEPTOR,
      useClass: NoIndexInterceptor,
    },
  ],
})
export class AppModule {}
```

## 2. Protección de Documentación Swagger/OpenAPI (`src/main.ts`)

En producción, deshabilita Swagger o restríngelo mediante autenticación básica:

```ts
if (process.env.NODE_ENV !== 'production') {
  const config = new DocumentBuilder()
    .setTitle('API Docs')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);
}
```

## 3. Endpoints Públicos de Sitemap y Robots (`src/modules/seo/seo.controller.ts`)

Si NestJS aloja la raíz del dominio:

```ts
import { Controller, Get, Header } from '@nestjs/common';

@Controller()
export class SeoController {
  @Get('robots.txt')
  @Header('Content-Type', 'text/plain')
  getRobots(): string {
    return `User-agent: *\nDisallow: /api/\nSitemap: https://example.com/sitemap.xml`;
  }
}
```
