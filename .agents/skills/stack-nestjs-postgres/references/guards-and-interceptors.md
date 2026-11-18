# NestJS Guards, Interceptors & Filters Reference

Convenciones para seguridad, autenticación y normalización de respuestas HTTP en NestJS.

---

## 1. Guards de Autenticación y RBAC (`RolesGuard`)

```typescript
// src/common/guards/roles.guard.ts
import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

export const ROLES_KEY = 'roles';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }

    const { user } = context.switchToHttp().getRequest();
    if (!user || !requiredRoles.includes(user.role)) {
      throw new ForbiddenException({
        success: false,
        error: { code: 'FORBIDDEN', message: 'No tienes permisos para este recurso' },
      });
    }

    return true;
  }
}
```

---

## 2. Interceptor de Respuesta Canónica

Garantiza que todas las respuestas 2xx sigan el contrato `{ success: true, data }`:

```typescript
// src/common/interceptors/transform.interceptor.ts
import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export interface Response<T> {
  success: boolean;
  data: T;
}

@Injectable()
export class TransformInterceptor<T> implements NestInterceptor<T, Response<T>> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<Response<T>> {
    return next.handle().pipe(map((data) => ({ success: true, data })));
  }
}
```

---

## 3. Filtro Centralizado de Excepciones

Evita filtrar detalles de la base de datos o trazas de ejecución en producción:

```typescript
// src/common/filters/http-exception.filter.ts
import { ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus } from '@nestjs/common';
import { Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const message =
      exception instanceof HttpException
        ? exception.getResponse()
        : 'Error interno del servidor';

    response.status(status).json({
      success: false,
      error: {
        code: status === 500 ? 'INTERNAL_ERROR' : 'HTTP_ERROR',
        message: typeof message === 'object' ? (message as any).message || message : message,
      },
    });
  }
}
```
