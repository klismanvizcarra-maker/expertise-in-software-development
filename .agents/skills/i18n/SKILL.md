---
name: i18n
description: Traduce e internacionaliza apps Angular + Express - textos traducibles con @angular/localize (atributo i18n, $localize, plurales ICU), extracción y archivos XLIFF por idioma, builds y rutas por idioma (/es/, /en/), fechas, números y monedas según el locale, mensajes de error de la API por código y emails en el idioma del usuario. Usar al traducir textos o pantallas a otro idioma (inglés, español...), cuando la app debe salir en más de un idioma o al añadir un idioma nuevo. No usar para apps de un solo idioma.
---

# Internacionalización (i18n)

Estrategia del sistema: **traducción en tiempo de compilación con `@angular/localize`** (oficial, sin dependencias y sin coste en ejecución). Cada idioma es un build propio servido bajo su ruta (`/es/`, `/en/`); cambiar de idioma recarga la página. Verificado con Angular 22 + SSR.

## 1. Configuración Inicial
```bash
cd apps/web && npx ng add @angular/localize
```
En `angular.json` (proyecto web):
```json
"i18n": {
  "sourceLocale": "es",
  "locales": { "en": { "translation": "src/locale/messages.en.xlf" } }
}
```
y en `architect.build.options`: `"localize": true` (genera `dist/web/browser/es` y `dist/web/browser/en`, y lo mismo para el servidor SSR). Para trabajar en un idioma concreto en desarrollo, añade la configuración de build `"en": { "localize": ["en"] }` y la de `serve` con `"buildTarget": "web:build:development,en"`, y ejecuta `ng serve --configuration=en`.

## 2. Marcar Textos
- Plantillas: `<h1 i18n="@@home.title">Reserva en segundos</h1>`; atributos con `i18n-alt="@@home.heroAlt"`, `i18n-placeholder`, `i18n-aria-label`.
- TypeScript: `$localize\`:@@orders.deleted:Pedido eliminado\``.
- Plurales y variantes con ICU: `{count, plural, =0 {Sin reservas} =1 {Una reserva} other {{{count}} reservas}}`.
- **IDs explícitos siempre** (`@@modulo.clave`): sin ellos, cambiar una coma del texto original invalida la traducción.
- No concatenes fragmentos traducidos ("Hola " + nombre): usa interpolación dentro del mensaje para que el traductor controle el orden.

## 3. Flujo de Traducción
```bash
npx ng extract-i18n --output-path src/locale    # genera/actualiza src/locale/messages.xlf (idioma fuente)
```
1. Copia las unidades nuevas de `messages.xlf` a cada `messages.<locale>.xlf` y añade su `<target>`.
2. **Comprueba que no falte ningún `<target>`**. Angular solo falla el build si falta la unidad entera; si la unidad existe sin `<target>`, sale en el idioma original **sin avisar** (comprobado):
   ```bash
   for f in src/locale/messages.*.xlf; do
     u=$(grep -c '<trans-unit' "$f"); t=$(grep -c '<target' "$f")
     [ "$u" = "$t" ] || { echo "❌ $f: $((u - t)) textos sin traducir"; exit 1; }
   done
   ```
   Añade esta comprobación al pipeline de CI y al checklist de QA.
3. Commit de los `.xlf` junto al código que los origina.

## 4. Formatos según el Idioma
- Cada build fija su `LOCALE_ID`: los pipes `date`, `number`, `currency` y `percent` formatean automáticamente.
- Fechas en UTC (`timestamptz`) en la API; se formatean en el cliente. Zona horaria del usuario si el negocio lo requiere (guárdala en su perfil).
- Dinero: céntimos + código ISO de moneda en la API; `{{ totalCents / 100 | currency: order.currency }}` en la plantilla.

## 5. Backend
- La API **no devuelve textos traducidos**: devuelve códigos (`ERR_VALIDATION_FAILED`, `ERR_PLAN_REQUIRED`) y Angular los traduce con `$localize`. Los errores de validación incluyen el campo y la regla, no la frase.
- Lo que la API sí redacta (emails, PDFs, notificaciones push) usa el idioma guardado en el perfil del usuario (`users.locale`), con plantillas por idioma.
- Al registrarse, el idioma inicial sale del build desde el que se registró el usuario.

## 6. Rutas, SEO y Despliegue
- El servidor (SSR o proxy) redirige `/` al idioma preferido: cookie del usuario → `Accept-Language` → idioma fuente.
- El selector de idioma enlaza a la misma página en la otra ruta (`/en/precios`) y guarda la preferencia en una cookie.
- Cada idioma tiene su canonical y las etiquetas `hreflang` alternas (ver `seo-web`); el `<html lang>` lo pone el build.

## Checklist antes de `task.sh handoff`
- [ ] Ningún texto visible sin marcar (revisa plantillas nuevas, `aria-label`, `alt`, `placeholder` y toasts).
- [ ] `ng extract-i18n` ejecutado y todos los idiomas con `<target>` completos (comprobación del paso 3).
- [ ] Build `localize` correcto y revisado en cada idioma (textos largos sin romper el diseño, fechas y monedas bien formateadas).
