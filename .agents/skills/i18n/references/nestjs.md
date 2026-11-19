# Internacionalización (i18n) — NestJS + PostgreSQL

Receta de referencia para `stack-nestjs-postgres`. Aborda la resolución de idioma mediante cabecera `Accept-Language`, mensajes de validación internacionalizados con `nestjs-i18n` o códigos semánticos, y correos transaccionales localizados.

## 1. Configuración de `nestjs-i18n` (`src/app.module.ts`)

```ts
import { Module } from '@nestjs/common';
import * as path from 'path';
import {
  I18nModule,
  AcceptLanguageResolver,
  QueryResolver,
  HeaderResolver,
} from 'nestjs-i18n';

@Module({
  imports: [
    I18nModule.forRoot({
      fallbackLanguage: 'es',
      loaderOptions: {
        path: path.join(__dirname, '/i18n/'),
        watch: process.env.NODE_ENV !== 'production',
      },
      resolvers: [
        new HeaderResolver(['x-custom-lang']),
        new AcceptLanguageResolver(),
        new QueryResolver(['lang', 'locale']),
      ],
    }),
  ],
})
export class AppModule {}
```

## 2. Catálogos JSON en Backend (`src/i18n/es/mail.json`, `src/i18n/en/mail.json`)

```json
// src/i18n/es/mail.json
{
  "welcome": {
    "subject": "Bienvenido a {appName}",
    "body": "Hola {name}, gracias por unirte a nuestro servicio."
  }
}
```

```json
// src/i18n/en/mail.json
{
  "welcome": {
    "subject": "Welcome to {appName}",
    "body": "Hello {name}, thank you for joining our service."
  }
}
```

## 3. Códigos Semánticos de Error para APIs

Para endpoints de API consumidos por clientes web o móviles (Flutter, React, Angular), es una mejor práctica devolver códigos de error semánticos (`code`) en lugar de strings traducidas:

```ts
// src/common/filters/http-exception.filter.ts
import { ExceptionFilter, Catch, ArgumentsHost, HttpException } from '@nestjs/common';
import { Response } from 'express';

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const status = exception.getStatus();
    const resObj = exception.getResponse() as any;

    response.status(status).json({
      statusCode: status,
      code: resObj.code || 'REQUEST_FAILED',
      message: resObj.message,
      timestamp: new Date().toISOString(),
    });
  }
}
```
Esto permite al cliente traducir el error respetando su propio estado y pluralización ICU.
