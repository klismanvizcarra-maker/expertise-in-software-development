# i18n — FastAPI + PostgreSQL

En un backend API puro, la internacionalización cubre **códigos de error estables**, **negociación de locale para notificaciones/PDFs/emails**, **persistencia del idioma del usuario** y **formateo neutro de datos**.

## 1. Contrato de errores sin texto traducido en API

- Devuelve siempre un código máquina invariable y metadatos seguros:

```python
from fastapi import HTTPException, status

raise HTTPException(
    status_code=status.HTTP_403_FORBIDDEN,
    detail={"code": "ERR_PLAN_REQUIRED", "params": {"required_plan": "pro"}},
)
```

- Prohibido traducir mensajes de validación o negocio dentro de la respuesta JSON para sustituir al catálogo del frontend: rompe clientes móviles, webhooks y tests de contrato.

## 2. Resolución de locale en dependencias y perfil de usuario

- Guarda `locale` en la tabla `users` (validado contra `SUPPORTED_LOCALES = ("es", "en")`, fallback `"es"`).
- Para endpoints que sí generan contenido humano (emails transaccionales, facturas PDF, resúmenes), resuelve el locale con una dependencia dedicada:

```python
from fastapi import Header

SUPPORTED_LOCALES = ("es", "en")
DEFAULT_LOCALE = "es"

def _parse_q(params: list[str]) -> float:
    for param in params:
        if param.strip().startswith("q="):
            try:
                return float(param.strip()[2:])
            except ValueError:
                return 0.0
    return 1.0

def resolve_locale(accept_language: str | None = Header(default=None)) -> str:
    if not accept_language:
        return DEFAULT_LOCALE
    candidates: list[tuple[float, str]] = []
    for part in accept_language.split(","):
        segments = part.split(";")
        tag = segments[0].strip().lower().split("-")[0]
        q = _parse_q(segments[1:])
        if q > 0 and tag in SUPPORTED_LOCALES:
            candidates.append((q, tag))
    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][1] if candidates else DEFAULT_LOCALE
```

- Prioridad recomendada cuando hay usuario autenticado: `user.locale` (preferencia guardada) → cabecera `Accept-Language` → `DEFAULT_LOCALE`.

## 3. Emails, plantillas y formatos

- Almacena y serializa fechas en UTC (`datetime.timezone.utc` / `TIMESTAMPTZ`) e importes monetarios en céntimos enteros (`int`).
- Para correos o PDFs multi-idioma en Python usa catálogos `gettext`/Babel (`.po`/`.mo`) o diccionarios tipados por locale verificados en CI (`pytest` validando que todas las claves existen en cada idioma soportado).
- Si usas `Jinja2` con emails HTML, habilita siempre `autoescape=True` para evitar XSS en correos renderizados desde datos del usuario.
