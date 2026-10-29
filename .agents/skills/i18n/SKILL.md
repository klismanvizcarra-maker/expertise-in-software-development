---
name: i18n
description: Traduce e internacionaliza apps Angular + Express - textos traducibles con @angular/localize (atributo i18n, $localize, plurales ICU), extracción y archivos XLIFF por idioma, builds y rutas por idioma (/es/, /en/), fechas, números y monedas según el locale, mensajes de error de la API por código y emails en el idioma del usuario. Usar al traducir textos o pantallas a otro idioma (inglés, español...), cuando la app debe salir en más de un idioma o al añadir un idioma nuevo. No usar para apps de un solo idioma.
---

# Internacionalización (i18n)

Estrategia del sistema: **traducción en tiempo de compilación con `@angular/localize`** (oficial, sin dependencias externas y con cero sobrecoste en tiempo de ejecución). Cada idioma genera su propio build servido bajo su ruta dedicada (`/es/`, `/en/`). Verificado con Angular 22 + SSR.

## Protocolo

1. **Configuración de Locales**: instala `@angular/localize` y declara el idioma fuente (`sourceLocale`) y los idiomas destino (`locales`) en `angular.json`.
2. **Marcado de Contenidos**: etiqueta textos en plantillas con `i18n="@@modulo.clave"` y en TypeScript con `$localize\`:@@modulo.clave:Texto\``.
3. **Extracción y Traducción**: extrae los mensajes fuente con `ng extract-i18n`, sincroniza los archivos `.xlf` de cada idioma y completa las etiquetas `<target>`.
4. **Formateo y Dominio**: implementa pipes para fechas, monedas y números sensibles al locale; configura la API backend para retornar códigos semánticos de error en lugar de cadenas traducidas.
5. **Enrutamiento y Redirección**: configura el proxy inverso o SSR para resolver el locale inicial (cookie → `Accept-Language` → idioma por defecto).
6. **Compilación y Verificación**: valida que no existan unidades sin traducir con el script de comprobación y verifica los builds de cada idioma.

---

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

## 2. Marcar Textos y Mensajes
- **Plantillas HTML**: `<h1 i18n="@@home.title">Reserva en segundos</h1>`; atributos accesibles con `i18n-alt="@@home.heroAlt"`, `i18n-placeholder`, `i18n-aria-label`.
- **TypeScript**: `$localize\`:@@orders.deleted:Pedido eliminado\``.
- **Plurales y género con ICU**: `{count, plural, =0 {Sin reservas} =1 {Una reserva} other {{{count}} reservas}}`.
- **IDs semánticos explícitos siempre** (`@@modulo.clave`): sin ellos, cambiar una coma del texto original rompe la asociación de traducción.
- Prohibida la concatenación manual de cadenas (`"Hola " + nombre`). Usa siempre interpolación dentro del mensaje (`Hola {{nombre}}`).

## 3. Flujo de Extracción y Sincronización
```bash
npx ng extract-i18n --output-path src/locale    # genera/actualiza src/locale/messages.xlf (fuente)
```
1. Copia las unidades nuevas de `messages.xlf` a cada `messages.<locale>.xlf` y completa el elemento `<target>`.
2. **Comprobación obligatoria de etiquetas `<target>`**: Angular no advierte si una unidad existe sin `<target>`; simplemente emite el texto original sin aviso. Ejecuta:
   ```bash
   for f in src/locale/messages.*.xlf; do
     u=$(grep -c '<trans-unit' "$f"); t=$(grep -c '<target' "$f")
     [ "$u" = "$t" ] || { echo "❌ $f: $((u - t)) textos sin traducir"; exit 1; }
   done
   ```
3. Versiona los archivos `.xlf` junto con los cambios de código correspondientes.

## 4. Adaptación Backend y Formatos
- La API REST **nunca devuelve textos traducidos**: devuelve códigos estructurados (`ERR_VALIDATION_FAILED`, `ERR_PLAN_REQUIRED`) y el cliente los localiza.
- Las comunicaciones emitidas por el backend (correos electrónicos, PDFs, notificaciones push) utilizan el idioma guardado en el perfil del usuario (`users.locale`).
- Fechas almacenadas siempre en UTC (`timestamptz`); formateadas en cliente mediante pipes (`date`). Monedas con céntimos enteros en API (`currency`).

## 5. Rutas, SEO y Detección
- El servidor (SSR o Nginx) redirige `/` según: cookie de preferencia → cabecera `Accept-Language` → idioma fuente.
- Cada idioma cuenta con su URL canónica y etiquetas `hreflang` cruzadas (ver `seo-web`).

## Checklist antes de `task.sh handoff`
- [ ] Todo texto visible, atributo accesible (`aria-label`, `alt`, `placeholder`) y notificación toast cuenta con su identificador `i18n="@@id"`.
- [ ] Ejecutado `ng extract-i18n` y verificado que el 100% de los `<trans-unit>` cuentan con su correspondiente `<target>`.
- [ ] Build multilingüe (`npm run build`) compilado con éxito para todos los idiomas configurados.
- [ ] La API devuelve códigos de error semánticos, sin cadenas fijas en lenguaje natural.
- [ ] Formateo de fechas, números y monedas verificado en cada idioma soportado.

## Prohibido
- Concatenar fragmentos de texto traducidos con operadores `+` en TypeScript o plantillas.
- Dejar textos visibles sin marcar con atributo `i18n` o `$localize`.
- Retornar cadenas traducidas en respuestas de error de la API (solo códigos semánticos).
- Dejar unidades `<trans-unit>` sin etiqueta `<target>` en archivos `.xlf`.
