# i18n — Angular 22 + Express 5

Estrategia de referencia: traducción en tiempo de compilación con `@angular/localize` (sin dependencias de runtime) y un build dedicado por idioma servido bajo `/es/`, `/en/`. Verificado con Angular 22 + `@angular/ssr`.

## 1. Configuración en Angular

```bash
cd apps/web && npx ng add @angular/localize
```

En `apps/web/angular.json`:

```json
"i18n": {
  "sourceLocale": "es",
  "locales": {
    "en": { "translation": "src/locale/messages.en.xlf" }
  }
}
```

En `architect.build.options`, activa `"localize": true` (genera `dist/web/browser/es` y `dist/web/browser/en`). Para desarrollo local en otro idioma añade configuración `"en": { "localize": ["en"] }` y `"serve"` con `"buildTarget": "web:build:development,en"`.

## 2. Marcado de textos e ICU

- Plantillas HTML: `<h1 i18n="@@home.title">Reserva en segundos</h1>`; atributos accesibles con `i18n-alt="@@home.heroAlt"`, `i18n-placeholder`, `i18n-aria-label`.
- TypeScript: ``$localize`:@@orders.deleted:Pedido eliminado` ``.
- Plurales ICU: `{count, plural, =0 {Sin reservas} =1 {Una reserva} other {{{count}} reservas}}`.
- Pipes de Angular (`DatePipe`, `CurrencyPipe`, `DecimalPipe`) consumen automáticamente `LOCALE_ID` del build activo; asegúrate de registrar el locale de datos (`registerLocaleData`) si usas un locale fuera de `en-US`.

## 3. Extracción y verificación obligatoria de `<target>`

```bash
npx ng extract-i18n --output-path src/locale
for f in src/locale/messages.*.xlf; do
  u=$(grep -c '<trans-unit' "$f")
  t=$(grep -c '<target' "$f")
  [ "$u" = "$t" ] || { echo "❌ $f: $((u - t)) textos sin traducir"; exit 1; }
done
```

Angular no falla cuando falta `<target>` en un archivo `.xlf`: simplemente emite el idioma fuente sin aviso; por eso este script debe correr antes de entregar.

## 4. API Express y SSR

- Express resuelve el error mediante el contrato estándar `{ success: false, error: { code: 'ERR_PLAN_REQUIRED', message: '...' } }`, manteniendo estable `error.code` para que el cliente lo traduzca con su catálogo.
- El servidor SSR o Nginx redirige `/` usando: cookie `app_locale`/`lang` → cabecera `Accept-Language` → `sourceLocale`.
- Emite URL canónica por idioma y `<link rel="alternate" hreflang="...">` en `SeoService` (ver skill `seo-web`).
