---
name: stack-[nombre-del-stack]
description: Stack [Frontend] + [Backend] + [Base de Datos] - [3 o 4 piezas distintivas: carpetas, librerías, gotchas]. Usar cuando el proyecto use [tecnología distintiva]. No usar para [stack vecino] (stack-[vecino]).
---

# Stack: [Nombre del Stack Tecnológico]

Esta skill fija el **cómo concreto de la implementación**; las skills de los roles especialistas (`frontend-agent`, `backend-agent`, etc.) definen el proceso. Si una convención específica de este stack contradice una regla genérica de rol, prevalece la de este archivo. Cualquier excepción debe registrarse como un ADR en `GLOBAL_STATE.md` §6.

> **Guía rápida para crear un stack adicional (`stack-<nombre>`)**:
> 1. Copia esta plantilla a `.agents/skills/stack-<nombre>/SKILL.md` (por ejemplo, `stack-go-gin-postgres` o `stack-django-postgres`) y sustituye `name:` en el frontmatter para que coincida con el directorio.
> 2. Rellena `description` (300 caracteres como máximo) con lo que distingue a este stack, cuándo activarse (`Usar cuando...`) y el límite frente al stack más parecido (`No usar para...`). Evita la plantilla común de los demás stacks: palabras repetidas hacen que el modelo los confunda.
> 3. Declara las rutas reales por rol en `AGENTS.md` §8 (matriz de propiedad de código) y actualiza el stack activo en `GLOBAL_STATE.md` §2.
> 4. Si tu toolchain es distinto de Node 24 o Python 3.12 (`pyproject.toml`/`requirements.txt`), adapta `.github/workflows/audit.yml` (o `.agents/templates/ci_workflow_template.yml`) añadiendo los pasos equivalentes de lint, tipos, tests y build con Actions fijadas por SHA.
> 5. Valida la nueva skill con `bash tests/test-skills.sh` (y `python3 tests/triggers/lint_descriptions.py` tras añadir casos en `tests/triggers/cases.json`).

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

