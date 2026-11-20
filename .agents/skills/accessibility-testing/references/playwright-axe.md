# Recetas de Automatización con Playwright y Axe-Core

Integración estándar para suites de pruebas automatizadas con `@axe-core/playwright`.

---

## 1. Instalación y Configuración

```bash
npm install -D @axe-core/playwright
```

## 2. Test Canónico de Página Completa

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Auditoría de Accesibilidad', () => {
  test('la página de inicio no debe tener violaciones WCAG 2.1 AA', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });
});
```

## 3. Escaneo de Componente Específico (Modal o Formulario)

```typescript
test('el modal de checkout cumple accesibilidad al abrirse', async ({ page }) => {
  await page.goto('/checkout');
  await page.click('button#abrir-pago');
  await page.waitForSelector('[role="dialog"]');

  const results = await new AxeBuilder({ page })
    .include('[role="dialog"]')
    .analyze();

  expect(results.violations).toEqual([]);
});
```

## 4. Diagnóstico Detallado de Violaciones

```typescript
if (accessibilityScanResults.violations.length > 0) {
  console.log('Violaciones encontradas:');
  for (const violation of accessibilityScanResults.violations) {
    console.log(`- [${violation.id}] ${violation.description}`);
    console.log(`  Ayuda: ${violation.helpUrl}`);
    console.log(`  Nodos afectados: ${violation.nodes.length}`);
  }
}
```
