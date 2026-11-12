# Subidas Directas Pre-firmadas y Emails Transaccionales

## 1. Flujo seguro de subida de archivos (Direct-to-Object-Storage)

Nunca enrutes archivos grandes (vídeos, PDFs, imágenes pesadas) a través del servidor de API ni los guardes en el disco efímero del contenedor: satura memoria/hilos y se pierde en el siguiente despliegue.

1. **Solicitud de permiso (`POST /api/v1/uploads/presign`)**:
   - Autenticada y autorizada (propiedad/cuota del tenant).
   - El cliente envía `{ filename, contentType, sizeBytes }`; el servidor valida contra lista blanca estricta (`image/png`, `image/jpeg`, `application/pdf`, tope de bytes exacto). **Nunca aceptes `image/svg+xml` sin sanitizar o servir en dominio aislado** (riesgo XSS; ver `security-hardening`).
   - Genera clave aleatoria en el servidor (`uploads/${tenantId}/${uuid}`) ignorando rutas relativas (`../`) y nombres originales como clave S3/R2/GCS.
   - Emite URL pre-firmada `PUT`/`POST` de corta duración (60–300 s) con condiciones firmadas de `Content-Type` y `content-length-range`.
2. **Confirmación y verificación asíncrona (`POST /api/v1/uploads/:id/complete` + worker)**:
   - Un job en segundo plano descarga los primeros bytes / cabecera de objeto para verificar **magic bytes** reales (rechaza ejecutables o HTML disfrazados de `.jpg`), inspecciona tamaño final, escanea si aplica (`ClamAV`/servicio) y genera miniaturas/derivados borrando metadatos EXIF.
   - Hasta completar la validación el registro queda en `PENDING_SCAN`; nunca se sirve como público antes de validarse.
3. **Entrega segura**: sirve descargas desde dominio separado o mediante URL pre-firmada `GET` temporal con `Content-Disposition: attachment` para adjuntos de usuario.

## 2. Envío de emails transaccionales

1. **Desacoplado en Outbox / Cola**:
   - El endpoint guarda el pedido/registro y escribe un `outbox_event` (`email.order_confirmed` con `{ user_id, locale, template_vars }` mínimos). Prohibido llamar a Resend/SES/SendGrid bloqueando la respuesta HTTP cuando el email no define el resultado de la operación.
2. **Plantillas, XSS e i18n**:
   - Resuelve el idioma con la preferencia guardada `user.locale` (o dependencia de `i18n`), nunca texto duro en un único idioma.
   - Si renderizas HTML con motores de plantillas (`Jinja2` / `React Email` / `Handlebars`), mantén **`autoescape=True` / escape estricto** en toda variable proveniente del usuario (nombre, dirección, comentario).
   - Incluye versión `text/plain` junto a la versión HTML para accesibilidad y entregabilidad.
3. **Idempotencia y webhooks del proveedor**:
   - Pasa `Idempotency-Key: <email_event_id>` si el proveedor lo soporta y guarda `provider_message_id` + tabla de suprimidos (*hard bounces* / *complaints* recibidos por webhook firmado) para no seguir enviando a direcciones rebotadas y dañar la reputación del dominio.
   - **Privacidad en logs**: registra `{ job_id, template, status, provider_message_id }`; nunca registres enlaces de restablecimiento de contraseña, códigos OTP ni cuerpos HTML completos.
