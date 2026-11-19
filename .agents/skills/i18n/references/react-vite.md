# Internacionalización (i18n) — React 19 + Vite + Node

Receta de referencia para `stack-react-vite-node`. Utiliza `i18next` y `react-i18next` con carga asíncrona de recursos en `client/` para evitar inflar el bundle inicial con todos los idiomas.

## 1. Configuración de i18next (`client/src/i18n.ts`)

```ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';
import HttpBackend from 'i18next-http-backend';

i18n
  .use(HttpBackend) // Carga dinámica desde /locales/{{lng}}/{{ns}}.json
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    fallbackLng: 'es',
    supportedLngs: ['es', 'en'],
    defaultNS: 'common',
    interpolation: {
      escapeValue: false, // React ya escapa contra XSS
    },
    backend: {
      loadPath: '/locales/{{lng}}/{{ns}}.json',
    },
  });

export default i18n;
```

## 2. Uso en Componentes React 19 (`client/src/components/`)

```tsx
import { useTranslation } from 'react-i18next';

export function LanguageSelector() {
  const { i18n, t } = useTranslation('common');

  const changeLanguage = (lng: string) => {
    i18n.changeLanguage(lng);
    document.documentElement.lang = lng;
  };

  return (
    <div>
      <p>{t('greeting', { name: 'Klisman' })}</p>
      <button onClick={() => changeLanguage('es')}>ES</button>
      <button onClick={() => changeLanguage('en')}>EN</button>
    </div>
  );
}
```

## 3. Contratos de Error en Servidor Express (`server/`)

El servidor Express nunca devuelve cadenas de error en lenguaje natural fijas:
```ts
// server/src/middlewares/error.middleware.ts
export function errorHandler(err: any, req: Request, res: Response, next: NextFunction) {
  res.status(err.status || 500).json({
    code: err.code || 'INTERNAL_ERROR',
    message: err.message, // Para logs internos
    details: err.details,
  });
}
```
El cliente React captura el código semántico (`code`) y lo traduce usando su catálogo local: `t(`errors.${res.code}`)`.
