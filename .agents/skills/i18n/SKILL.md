---
name: i18n
description: Internacionalización de webs y APIs - catálogos por idioma, plurales ICU, rutas por locale y formatos regionales de fecha, número y moneda. Usar al traducir pantallas o añadir un idioma. No usar para apps de un solo idioma.
---

# Internacionalización (i18n)

Principio del sistema: **el idioma fuente se marca con identificadores semánticos explícitos (`modulo.clave`), los textos nunca se concatenan, la API responde códigos máquina y las fechas/monedas viajan en formato neutro (UTC y céntimos enteros).**

## Recetas por stack
Carga la referencia que corresponda al stack del proyecto (`GLOBAL_STATE.md` §2):
- **Angular + Express**: [references/angular-express.md](references/angular-express.md) (`@angular/localize`, `.xlf` y extracción en build)
- **Next.js + Prisma**: [references/nextjs.md](references/nextjs.md) (rutas `[locale]`, catálogos JSON en servidor y `Intl`)
- **FastAPI + PostgreSQL**: [references/fastapi.md](references/fastapi.md) (códigos de error, `Accept-Language`, perfil de usuario y correos localizados)
- **Vue + Nuxt + Drizzle**: [references/nuxt.md](references/nuxt.md) (`@nuxtjs/i18n`, rutas prefijadas y catálogos JSON lazy)
- **React + Vite + Node**: [references/react-vite.md](references/react-vite.md) (`i18next`, carga asíncrona de namespaces y errores semánticos)
- **NestJS + PostgreSQL**: [references/nestjs.md](references/nestjs.md) (`nestjs-i18n`, resolución por cabecera y filtros globales)
- **Otro stack**: aplica este protocolo agnóstico y registra la elección de librería en un ADR (`docs-architecture-agent`).

## Protocolo

1. **Configuración de locales**: define el idioma fuente (`sourceLocale`), la lista cerrada de idiomas soportados (`es`, `en`, ...) y el mecanismo de detección (`cookie` o `users.locale` → `Accept-Language` → idioma por defecto).
2. **Marcado de contenidos**: etiqueta todos los textos visibles, notificaciones y atributos accesibles (`alt`, `placeholder`, `aria-label`) con IDs semánticos (`modulo.clave`), nunca con hashes dependientes del texto literal.
3. **Plurales e interpolación**: usa sintaxis ICU o equivalentes locales para plurales y género; prohíbe concatenar frases traducidas con `+`.
4. **Extracción y paridad de catálogos**: extrae o valida los archivos de traducción (`.xlf`, `.json`, `.po`) y verifica de forma automatizada que el 100 % de las claves tienen traducción en todos los idiomas.
5. **Adaptación backend y formatos**: la API devuelve códigos de error (`ERR_VALIDATION_FAILED`, `ERR_PLAN_REQUIRED`) y guarda fechas en UTC (`timestamptz`) e importes en céntimos enteros; la capa de presentación formatea según el locale activo y el backend localiza emails o PDFs usando `users.locale`.
6. **Rutas y SEO cruzado**: expone rutas dedicadas por idioma (`/es/`, `/en/`) con `<html lang>`, URL canónica por idioma y etiquetas `hreflang` cruzadas (ver skill `seo-web`).

## Checklist antes de `task.sh handoff`
- [ ] Todo texto visible, atributo accesible (`aria-label`, `alt`, `placeholder`) y toast usa clave de traducción explícita.
- [ ] Comprobación automatizada de paridad del 100 % de traducciones entre idiomas en verde (sin claves vacías ni `<trans-unit>` sin `<target>`).
- [ ] Build multilingüe o suite de i18n compilada/pasada para todos los idiomas configurados.
- [ ] La API devuelve códigos de error semánticos, nunca texto libre traducido en JSON.
- [ ] Formateo de fechas, números y monedas y etiquetas `hreflang` verificados en cada idioma.

## Prohibido
- Concatenar fragmentos de texto traducidos con operadores `+` o plantillas partidas en lógica o vistas.
- Dejar textos visibles o atributos accesibles sin marcar en el catálogo de idiomas.
- Retornar cadenas traducidas en respuestas de error de la API (solo códigos semánticos).
- Entregar archivos de idioma incompletos (claves faltantes o unidades `<trans-unit>` sin `<target>`).
