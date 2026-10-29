---
name: e2e-testing
description: Escribe, ejecuta y depura pruebas end-to-end de aplicaciones web con Playwright - convierte los escenarios Gherkin del PRD en tests, usa selectores accesibles, datos de prueba aislados, autenticación reutilizable y trazas para depurar fallos inestables. Usar cuando hay que cubrir un flujo de usuario completo (login, checkout, formularios), validar una entrega de UI en QA o investigar un test E2E que falla. No usar para pruebas unitarias o de un endpoint aislado.
---

# E2E Testing con Playwright

Las pruebas E2E verifican flujos completos tal como los vive el usuario. Pocas y valiosas: un test por escenario crítico, no por componente.

## Estructura
```text
e2e/
├── playwright.config.ts
├── fixtures/        # usuarios de prueba, datos semilla, estado de sesión
└── specs/
    └── <funcionalidad>.spec.ts   # un archivo por PRD / historia de usuario
```
Instalación (una vez por proyecto): `npm i -D @playwright/test && npx playwright install --with-deps chromium`.

## Pasos

1. **Partir del PRD**: cada escenario Gherkin (`Dado / Cuando / Entonces`) de `docs/product/` se convierte en un `test()` con el mismo nombre (`US-001 · Escenario 2: datos inválidos`).
2. **Selectores accesibles**, en este orden de preferencia: `getByRole('button', { name: 'Confirmar' })`, `getByLabel`, `getByText`, y `getByTestId` solo como último recurso. Nunca selectores CSS de estructura (`div > span:nth-child(3)`).
3. **Esperas automáticas**: usa aserciones web-first (`await expect(locator).toBeVisible()`, `toHaveURL`, `toHaveText`). Prohibido `waitForTimeout`.
4. **Datos aislados**: cada test crea los datos que necesita (vía API o seed) y no depende del orden de ejecución ni de datos de otro test.
5. **Sesión reutilizable**: autentica una vez en un proyecto `setup` que guarda `storageState` y reutilízalo en los tests que requieren login; el flujo de login en sí se prueba aparte.
6. **Cubrir los 4 estados** de la matriz del PRD cuando aplique: interceptar la red con `page.route()` para forzar vacío, error 500 y lentitud (skeleton visible).
7. **Ejecutar**:
   ```bash
   npx playwright test                      # todos
   npx playwright test specs/login.spec.ts  # uno
   npx playwright test --ui                 # modo interactivo para depurar
   ```
8. **Depurar fallos**: configura `trace: 'on-first-retry'` y abre la traza con `npx playwright show-trace <archivo>`. Un test inestable (*flaky*) se corrige o se pone en cuarentena con una tarea; nunca se aumentan los reintentos para ocultarlo.

## Configuración Base
- `webServer` en `playwright.config.ts` levanta la app (y la API) antes de los tests, con `reuseExistingServer: !process.env.CI`.
- `baseURL` desde variable de entorno; `retries: process.env.CI ? 2 : 0`; `forbidOnly: !!process.env.CI`.
- En CI: solo Chromium salvo que el PRD exija otros navegadores; sube el reporte HTML como artefacto.
- El MCP `web-tester-playwright` sirve para explorar la página y descubrir selectores de forma interactiva; los tests definitivos viven en `e2e/specs/`.

## Checklist
- [ ] Cada escenario Gherkin crítico tiene su test.
- [ ] Sin `waitForTimeout` ni selectores CSS frágiles.
- [ ] Los tests pasan 3 veces seguidas en local (`--repeat-each=3`).
