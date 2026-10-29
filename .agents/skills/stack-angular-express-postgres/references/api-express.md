# Express 5 (Node 24) — Convenciones

## Estructura de `apps/api/src`
```text
app.ts                    # createApp(): monta middlewares y rutas, NO llama a listen (testeable con supertest)
server.ts                 # listen + cierre ordenado (SIGTERM/SIGINT → server.close → pool.end)
config/env.ts             # Variables de entorno validadas con Zod al arrancar (falla rápido)
db/client.ts · db/schema/ # Drizzle (ver database-drizzle.md)
middlewares/              # validate.ts, auth.ts, error-handler.ts, not-found.ts
lib/                      # api-response.ts (de .agents/templates/api_response_template.ts), logger.ts
modules/<modulo>/
├── <modulo>.routes.ts       # Router: ruta → middlewares → controlador
├── <modulo>.controller.ts   # Traduce HTTP ↔ servicio; sin reglas de negocio
├── <modulo>.service.ts      # Casos de uso; llama al dominio de @app/shared y al repositorio
└── <modulo>.repository.ts   # Consultas Drizzle
```

## Orden de Middlewares en `createApp()`
```ts
app.disable('x-powered-by');
app.set('trust proxy', 1);                         // si hay proxy/load balancer delante
app.use(helmet());
app.use(cors({ origin: env.CORS_ORIGIN, credentials: true }));
app.use(express.json({ limit: '100kb' }));
app.use(cookieParser());
app.use(pinoHttp({ logger, redact: ['req.headers.authorization', 'req.headers.cookie'] }));
app.get('/healthz', ...); app.get('/readyz', ...); // readyz hace SELECT 1
app.use('/api/v1/auth', authRateLimit, authRouter);
app.use('/api/v1/<modulo>', requireAuth, moduloRouter);
app.use(notFound);
app.use(errorHandler);                              // siempre el último
```

## Errores (Express 5)
- Los handlers `async` que lanzan o rechazan llegan **solos** al `errorHandler`: no envuelvas en `try/catch` ni uses `express-async-handler`.
- Lanza excepciones tipadas (`NotFoundException`, `ConflictException`... de `api_response_template.ts`); el `errorHandler` las traduce a `{ success: false, error: { code, message } }`.
- `ZodError` → 422 `ERR_VALIDATION_FAILED` con `details` por campo; error desconocido → 500 `ERR_INTERNAL` con mensaje genérico y log completo solo en el servidor.

## Validación
```ts
// middlewares/validate.ts
export const validate = (schemas: { body?: ZodType; params?: ZodType; query?: ZodType }) =>
  (req: Request, res: Response, next: NextFunction) => {
    if (schemas.body) req.body = schemas.body.parse(req.body);
    res.locals.params = schemas.params?.parse(req.params) ?? req.params;
    res.locals.query = schemas.query?.parse(req.query) ?? req.query;   // req.query es de solo lectura
    next();
  };
```
Los esquemas vienen de `@app/shared`; los de `params`/`query` pueden ser locales a la API.

## Configuración
```ts
// config/env.ts
const Env = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.url(),
  CORS_ORIGIN: z.string(),
  JWT_ACCESS_SECRET: z.string().min(32),
});
export const env = Env.parse(process.env);
```
En desarrollo, `node --env-file-if-exists=../../.env`; en producción, variables reales de la plataforma.

## Tests (Vitest + supertest)
- `request(createApp())` sin levantar el puerto.
- Base de datos de test real: `DATABASE_URL` apuntando a una base `app_test` migrada antes de la suite; cada test limpia lo que crea (o usa una transacción revertida).
- Por endpoint: éxito, 422 por validación, 401 sin token, 403 sin permiso, 404/403 sobre recurso ajeno.

## Logs
`pino` con `pino-http`; nunca registrar contraseñas, tokens, cookies ni cuerpos completos de peticiones de auth. En desarrollo, `pino-pretty` como transporte opcional.
