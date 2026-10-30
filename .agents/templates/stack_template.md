---
name: stack-[nombre-del-stack]
description: Convenciones, arquitectura, comandos canónicos y trampas conocidas del stack [Tecnología Frontend] + [Tecnología Backend] + [Base de Datos]. Usar siempre que se desarrolle, pruebe o despliegue código en un proyecto con este stack tecnológico.
---

# Stack: [Nombre del Stack Tecnológico]

Esta skill fija el **cómo concreto de la implementación**; las skills de los roles especialistas (`frontend-agent`, `backend-agent`, etc.) definen el proceso. Si una convención específica de este stack contradice una regla genérica de rol, prevalece la de este archivo. Cualquier excepción debe registrarse como un ADR en `GLOBAL_STATE.md` §6.

---

## 1. Versiones de Referencia y Piezas Principales

| Pieza | Tecnología / Librería | Versión Recomendada | Notas y Restricciones |
| :--- | :--- | :--- | :--- |
| **Runtime** | `[ej. Node.js / Python / Go / Bun]` | `[ej. 22 LTS / 3.12 / 1.23]` | `[Detalles de compatibilidad]` |
| **Frontend** | `[ej. Next.js / React / Vue / Angular]` | `[Versión]` | `[Modo de render, SSR, Client]` |
| **Backend / API**| `[ej. Next.js App Router / Express / FastAPI]`| `[Versión]` | `[Estructura de endpoints / Server Actions]` |
| **Persistencia** | `[ej. PostgreSQL / SQLite / MongoDB]` | `[Versión]` | `[Motor y extensiones requeridas]` |
| **ORM / Query** | `[ej. Prisma / Drizzle / SQLAlchemy]` | `[Versión]` | `[Gestión de migraciones schema-first]` |
| **Estilos & UI** | `[ej. Tailwind CSS / CSS Modules]` | `[Versión]` | `[Sistema de tokens y componentes]` |
| **Validación** | `[ej. Zod / Pydantic / Yup]` | `[Versión]` | `[Validación en runtime y tipos inferidos]` |
| **Testing** | `[ej. Vitest / Jest / Pytest / Playwright]` | `[Versión]` | `[Unitarias, integración y E2E]` |

---

## 2. Estructura Canónica de Directorios

```text
<proyecto>/
├── [archivo de dependencias]     # package.json, pyproject.toml, etc.
├── docker-compose.yml            # Servicios locales (BD, caché)
├── .env.example                  # Variables de entorno documentadas
├── [carpeta de código fuente]/
│   ├── [frontend/vistas]/        # Componentes y páginas
│   ├── [backend/api]/            # Endpoints, controladores y middlewares
│   ├── [persistencia]/           # Esquemas, modelos y migraciones
│   └── [dominio/compartido]/     # Reglas de negocio puras y contratos DTO
└── [tests]/                      # Pruebas automatizadas y suites E2E
```

---

## 3. Reglas de Oro del Stack

1. **Tipado Estricto de Contratos**: Todo contrato de entrada y salida debe definirse mediante un esquema de validación en runtime (`Zod`/`Pydantic`) del cual se infieran los tipos estáticos.
2. **Convención de Persistencia**: Las modificaciones al esquema de base de datos se realizan exclusivamente mediante migraciones versionadas y reversibles; prohibido alterar la base de datos de producción manualmente.
3. **Manejo Seguro de Secretos**: Ninguna credencial, clave de API o URL sensible se escribe en código fuente; se cargan mediante variables de entorno validadas al arrancar el servidor.
4. **Respeto a la Propiedad de Código**: Cada especialista modifica exclusivamente sus directorios designados (ver matriz de `AGENTS.md` §8).
5. **Precisión Numérica y Temporal**: Monedas y valores financieros se manejan siempre en enteros (céntimos); marcas temporales almacenadas obligatoriamente en UTC (`timestamptz` / ISO 8601).

---

## 4. Comandos Canónicos de Automatización

| Acción | Comando | Descripción |
| :--- | :--- | :--- |
| **Servicios locales** | `docker compose up -d` | Levanta base de datos y dependencias locales |
| **Desarrollo** | `npm run dev` | Inicia servidores en modo watch con hot reload |
| **Generar migración**| `npm run db:generate` | Crea el archivo de migración versionado |
| **Aplicar migración**| `npm run db:migrate` | Aplica migraciones pendientes sobre la BD |
| **Verificación tipos**| `npm run typecheck` | Comprobación estricta del compilador |
| **Tests unitarios** | `npm test` | Ejecuta la batería de pruebas |
| **Compilación build**| `npm run build` | Compila artefactos para producción |
| **Tests E2E** | `npx playwright test` | Ejecuta flujos completos de usuario |

---

## 5. Quirks y Trampas Conocidas (*Gotchas*)

| Tecnología | Comportamiento Inesperado | Regla de Prevención Obligatoria |
| :--- | :--- | :--- |
| **[Herramienta 1]** | `[Descripción del quirk]` | `[Solución preventiva técnica obligatoria]` |
| **[Herramienta 2]** | `[Descripción del quirk]` | `[Solución preventiva técnica obligatoria]` |

---

## 6. Checklist de Arquitectura del Stack
- [ ] Variables `.env.example` sincronizadas con todas las claves requeridas.
- [ ] Migraciones versionadas generadas y aplicadas sin intervención manual.
- [ ] Contratos DTO tipados e importados en frontend y backend.
- [ ] `typecheck` y build de producción finalizan con cero errores o warnings.
- [ ] Suites de pruebas pasando limpiamente en verde.

