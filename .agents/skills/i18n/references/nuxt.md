# Internacionalización (i18n) — Vue 3 + Nuxt 3

Receta de referencia para `stack-vue-nuxt-postgres`. Utiliza el módulo `@nuxtjs/i18n` para enrutamiento prefijado por idioma (`/es/`, `/en/`), catálogos JSON estructurados en `i18n/locales/` y formateo nativo ICU.

## 1. Configuración de Nuxt (`nuxt.config.ts`)

```ts
export default defineNuxtConfig({
  modules: ['@nuxtjs/i18n'],
  i18n: {
    locales: [
      { code: 'es', iso: 'es-ES', name: 'Español', file: 'es.json' },
      { code: 'en', iso: 'en-US', name: 'English', file: 'en.json' },
    ],
    defaultLocale: 'es',
    strategy: 'prefix_except_default', // '/en/about', '/about' (es)
    lazy: true,
    langDir: 'locales/',
    detectBrowserLanguage: {
      useCookie: true,
      cookieKey: 'i18n_redirected',
      redirectOn: 'root',
    },
  },
});
```

## 2. Catálogos y Formato ICU (`i18n/locales/es.json`, `en.json`)

```json
// i18n/locales/es.json
{
  "common": {
    "welcome": "Bienvenido, {name}",
    "itemsCount": "{count, plural, =0 {No hay elementos} =1 {1 elemento} other {# elementos}}"
  },
  "billing": {
    "upgrade": "Actualizar plan",
    "priceFormatted": "{amount, number, currency}"
  }
}
```

```json
// i18n/locales/en.json
{
  "common": {
    "welcome": "Welcome, {name}",
    "itemsCount": "{count, plural, =0 {No items} =1 {1 item} other {# items}}"
  },
  "billing": {
    "upgrade": "Upgrade plan",
    "priceFormatted": "{amount, number, currency}"
  }
}
```

## 3. Uso en Componentes Vue y Nitro

```vue
<!-- components/WelcomeBanner.vue -->
<script setup lang="ts">
const { t, d, n } = useI18n();
</script>

<template>
  <div class="banner">
    <h2>{{ t('common.welcome', { name: 'Usuario' }) }}</h2>
    <p>{{ t('common.itemsCount', { count: 3 }) }}</p>
  </div>
</template>
```

Para respuestas de error en endpoints Nitro (`server/api/**`), devuelve códigos de error semánticos (`{ code: "ERR_UNAUTHORIZED" }`) para que el cliente resuelva la traducción mediante su catálogo local.
