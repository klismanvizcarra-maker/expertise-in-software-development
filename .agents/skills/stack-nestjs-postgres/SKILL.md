---
name: stack-nestjs-postgres
description: Convenciones del stack backend NestJS (arquitectura modular en TypeScript) + Prisma o TypeORM + PostgreSQL, con validación DTO, Guards de autorización y Swagger/OpenAPI. Define estructura, inyección de dependencias, filtros globales y trampas conocidas. Usar siempre que se cree, modifique, pruebe o despliegue una API en NestJS. No usar para proyectos basados en stack-angular-express-postgres, stack-nextjs-tailwind-prisma, stack-fastapi-postgres, stack-vue-nuxt-postgres ni stack-react-vite-node.
---

# Stack: NestJS + TypeScript + PostgreSQL

Esta skill define el **cómo técnico concreto** para APIs backend empresariales construidas con el framework NestJS y persistencia sobre PostgreSQL; las skills de rol (`backend-agent`, `database-architect-agent`, etc.) rigen el proceso. Si una convención de este stack difiere de una regla genérica, prevalece esta especificación. Cualquier excepción debe registrarse como un ADR en `GLOBAL_STATE.md` §6.

---

## 1. Versiones de Referencia (verificadas 2026-11-18)

| Pieza | Versión | Notas |
| :--- | :--- | :--- |
| **Node.js** | 22 / 24 LTS | Runtime de ejecución y build |
| **NestJS** | 11.x / 10.x | Framework backend modular en TypeScript con inyección de dependencias |
| **TypeScript** | 5.6.x / 5.x | Tipado estricto con decoradores |
| **Validación** | `class-validator` 0.14+ / `zod` | Validación de DTOs con `ValidationPipe` estricto |
| **Persistencia** | Prisma 6+ o TypeORM 0.3+ | Cliente tipado con migraciones SQL versionadas |
| **PostgreSQL** | 16+ | Base de datos relacional; IDs con UUID |
| **Documentación** | `@nestjs/swagger` 8+ | Especificación OpenAPI 3.x generada desde decoradores |
| **Testing** | Jest / Vitest + Supertest | Pruebas unitarias de servicios y de integración e2e |

---

## 2. Estructura Canónica del Proyecto

```text
<proyecto>/
├── src/
│   ├── common/                   # Elementos transversales reutilizables
│   │   ├── decorators/           # Decoradores personalizados (@CurrentUser, @Roles)
│   │   ├── filters/              # HttpExceptionFilter global
│   │   ├── guards/               # JwtAuthGuard, RolesGuard
│   │   ├── interceptors/         # TransformInterceptor (salida canónica), LoggingInterceptor
│   │   └── pipes/                # Pipes de validación o transformación
│   ├── config/                   # Configuración de variables de entorno (@nestjs/config)
│   ├── modules/                  # Módulos de dominio aislados
│   │   ├── auth/                 # Módulo de autenticación (JWT, hashing)
│   │   │   ├── auth.controller.ts
│   │   │   ├── auth.service.ts
│   │   │   ├── auth.module.ts
│   │   │   └── strategies/
│   │   └── users/                # Módulo de usuarios
│   │       ├── dto/              # Data Transfer Objects con class-validator
│   │       ├── users.controller.ts
│   │       ├── users.service.ts
│   │       └── users.module.ts
│   ├── prisma/                   # Módulo de base de datos singleton (PrismaService)
│   ├── app.module.ts             # Módulo raíz que ensambla los submódulos
│   └── main.ts                   # Bootstrap de la aplicación NestJS
├── test/                         # Pruebas e2e con Supertest
├── prisma/                       # schema.prisma y migraciones
├── docker-compose.yml            # PostgreSQL local
└── .env.example                  # Variables de entorno documentadas
```

---

## 3. Reglas de Oro del Stack

1. **Inyección de Dependencias Estricta**: Prohibido instanciar servicios o repositorios directamente con `new`. Toda dependencia se declara en el constructor y se registra en `providers` del `@Module`.
2. **Validación Automática con `ValidationPipe`**: La aplicación configura globalmente en `main.ts`:
   ```typescript
   app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
   ```
   Propiedades no declaradas en el DTO se rechazan automáticamente (`forbidNonWhitelisted`).
3. **Módulos Cohesivos y Encapsulados**: Si un módulo necesita un servicio de otro, el módulo proveedor debe exportarlo explícitamente en `exports` y el consumidor debe importar el módulo en `imports`.
4. **Respuestas Canónicas**: Registrar globalmente `TransformInterceptor` para que toda respuesta devuelva `{ success: true, data }` y `HttpExceptionFilter` para que los errores nunca expongan detalles internos de la base de datos.
5. **Ciclo de Vida de Base de Datos Limpio**: Los servicios de base de datos implementan `OnModuleInit` y `OnModuleDestroy` para conectar y desconectar de forma controlada (`graceful shutdown`).
6. **Endpoints Documentados con OpenAPI**: Todo controlador expone `@ApiTags()`, `@ApiOperation()` y `@ApiResponse()` para alimentar la documentación interactiva en `/api/docs`.

---

## 4. Comandos Canónicos

| Acción | Comando |
| :--- | :--- |
| **Base de datos local** | `docker compose up -d` |
| **Servidor de desarrollo** | `npm run start:dev` |
| **Generar migración** | `npx prisma migrate dev` |
| **Aplicar migraciones** | `npx prisma migrate deploy` |
| **Linter y formato** | `npm run lint` / `npm run format` |
| **Tests unitarios** | `npm run test` |
| **Tests e2e** | `npm run test:e2e` |
| **Build de producción** | `npm run build` |

---

## 5. Referencias por Capa (leer la correspondiente)

- **Arquitectura Modular & DTOs**: [modular-architecture.md](references/modular-architecture.md)
- **Guards, Interceptores & Filtros**: [guards-and-interceptors.md](references/guards-and-interceptors.md)

---

## 6. Trampas Conocidas (*Gotchas*)

- **Dependencias Circulares entre Módulos**: Si dos módulos se importan mutuamente, NestJS fallará al arrancar con `Nest cannot resolve dependencies of the...`. Usa `forwardRef(() => ModuloB)` en `imports` e `@Inject(forwardRef(() => ServicioB))` en el constructor.
- **Payloads vacíos o campos omitidos**: Si `ValidationPipe({ transform: true })` no tiene decoradores en las propiedades del DTO (`@IsString()`, `@IsOptional()`), `class-transformer` ignorará esas propiedades y llegarán como `undefined`.
- **Excepciones no capturadas devuelven 500 genérico**: Si lanzas `new Error()` en vez de `new HttpException()` (ej. `NotFoundException`, `BadRequestException`), el cliente recibirá un 500 no descriptivo. Usa siempre las excepciones semánticas de `@nestjs/common`.
- **Habilitar CORS antes de los Middlewares**: Para clientes SPA o móviles, `app.enableCors()` debe invocarse en `main.ts` antes de escuchar peticiones en `app.listen()`.
