# i18n — Next.js 15 (App Router)

Estrategia de referencia para Next.js App Router: rutas prefijadas por locale (`app/[locale]/...`), catálogos JSON tipados cargados en Server Components (sin inflar el bundle cliente con diccionarios de otros idiomas) y API `Intl` nativa.

## 1. Enrutamiento por locale y detección

- Estructura: `app/[locale]/layout.tsx`, `app/[locale]/(marketing)/page.tsx`, etc., esperando `const { locale } = await params;` (Next.js 15) y validando `locale` contra una lista cerrada (`const LOCALES = ['es', 'en'] as const`); si no coincide, invoca `notFound()`.
- En `middleware.ts` (o librería `next-intl` con routing tipado): configura `config.matcher` excluyendo `/api/`, `/_next/` y archivos estáticos (`/favicon.ico`, assets con extensión), e inspecciona cookie explícita de idioma → cabecera `Accept-Language` → locale por defecto (`es`) para redirigir `/` → `/<locale>/` con estado HTTP adecuado.
- Fija `<html lang={locale}>` en `app/[locale]/layout.tsx` y `alternates.languages` en `generateMetadata()` (ver skill `seo-web`).

## 2. Catálogos de mensajes e ICU

- Mantén un archivo por idioma (`messages/es.json`, `messages/en.json`) agrupado por módulo (`home.title`, `billing.planRequired`), nunca claves planas anónimas ni concatenación con `+`.
- En Server Components pasa únicamente los strings necesarios a Client Components, o usa `NextIntlClientProvider` limitado al namespace que requiere interactividad.
- Script de paridad obligatorio antes de entregar (evita claves huérfanas, faltantes o cadenas vacías `""`):

```bash
node -e '
const fs = require("fs");
const es = JSON.parse(fs.readFileSync("messages/es.json", "utf8"));
const en = JSON.parse(fs.readFileSync("messages/en.json", "utf8"));
const flat = (o, p = "") => Object.entries(o).flatMap(([k, v]) => {
  const path = p ? `${p}.${k}` : k;
  if (v && typeof v === "object") return flat(v, path);
  if (typeof v !== "string" || v.trim() === "") throw new Error(`Empty value at ${path}`);
  return [path];
});
const a = new Set(flat(es)), b = new Set(flat(en));
const missingEn = [...a].filter(k => !b.has(k));
const missingEs = [...b].filter(k => !a.has(k));
if (missingEn.length || missingEs.length) {
  console.error({ missingEn, missingEs });
  process.exit(1);
}
'
```

## 3. Formateo y Route Handlers

- Usa `Intl.DateTimeFormat(locale, ...)` y `Intl.NumberFormat(locale, { style: 'currency', currency })` recibiendo fechas UTC ISO y céntimos enteros divididos solo en presentación.
- Los Route Handlers y Server Actions devuelven códigos de error semánticos (`{ error: { code: 'ERR_COUPON_EXPIRED' } }`) que el cliente traduce con su catálogo.
