# Modelado de Amenazas Ligero (STRIDE por funcionalidad)

Diez minutos por funcionalidad, antes de escribir código. El resultado va en la descripción o en los criterios de la tarea, no en un documento aparte.

## 1. Tres preguntas

1. **¿Qué datos toca?** Personales, de pago, credenciales, de otros usuarios, internos.
2. **¿Quién puede llamarla?** Anónimo, usuario autenticado, rol concreto, otro servicio, un webhook.
3. **¿Por dónde entra la entrada?** Cuerpo, query, cabeceras, archivos, URLs que da el usuario, datos de terceros.

## 2. STRIDE

| Amenaza | Pregunta | Control habitual |
| :--- | :--- | :--- |
| **S**poofing (suplantación) | ¿Puede alguien hacerse pasar por otro usuario o servicio? | Autenticación fuerte, firma de webhooks, tokens de vida corta |
| **T**ampering (manipulación) | ¿Puede alterar datos que no son suyos, o el precio, o el rol? | Autorización por objeto, valores críticos calculados en el servidor, validación estricta |
| **R**epudiation (repudio) | ¿Podría negar haber hecho una acción sensible? | Registro de auditoría con usuario, acción y fecha (ver skill `observability`) |
| **I**nformation disclosure (fuga) | ¿Puede ver datos ajenos, trazas o detalles internos? | Filtro por propietario, errores genéricos, campos de salida explícitos |
| **D**enial of service | ¿Puede agotar recursos con pocas peticiones? | Rate limiting, límites de tamaño, paginación obligatoria, timeouts |
| **E**levation of privilege | ¿Puede conseguir permisos que no tiene? | Roles comprobados en el servidor, sin asignación masiva de campos (`role`, `isAdmin`) |

## 3. Formato en la tarea

```text
Amenazas (STRIDE):
- T: un usuario cambia el total del pedido en el cuerpo → el total se recalcula en el servidor
- I: un usuario pide /orders/123 de otro → filtro por owner_id; test devuelve 404
- D: listado sin límite → paginación obligatoria, máximo 100 por página
```

Cada línea se convierte en un test o en un criterio de aceptación verificable.
