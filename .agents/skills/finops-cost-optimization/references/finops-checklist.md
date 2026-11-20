# Checklist y Reglas de Optimización de Costes Cloud (FinOps)

## 1. Computación y Serverless

- [ ] **Ajuste de Memoria Serverless**: Las funciones de Lambda / Cloud Functions / Serverless están dimensionadas según uso real (evitar 1024MB por defecto si la función usa 128MB).
- [ ] **Timeouts Estrictos**: Funciones HTTP con timeout máximo de 10-15s (previene cobros por ejecución suspendida ante caídas de dependencias).
- [ ] **Provisioned Concurrency Acotada**: Reservas fijas solo para endpoints críticos con SLA estricto; el resto bajo escalado a cero (*scale-to-zero*).
- [ ] **Contenedores**: `requests` fijados al percentil 90 del consumo histórico y `limits` al p99 para evitar sobreaprovisionamiento de nodos en Kubernetes/ECS.

## 2. Almacenamiento y Data Warehouses

- [ ] **Particionamiento y Proyección en Consultas**:
  - En BigQuery / Snowflake / Athena: Prohibido `SELECT *` en producción o jobs programados. Seleccionar solo columnas requeridas.
  - Filtrar obligatoriamente por la columna de partición (ej. `WHERE created_date >= CURRENT_DATE - 7`).
- [ ] **Ciclo de Vida de Objetos (S3 / GCS)**:
  - Transición a *Infrequent Access* tras 30 días.
  - Transición a *Archive / Glacier* tras 90 días para backups históricos.
  - Expiración de subidas multiparte incompletas (*abort incomplete multipart uploads*) tras 7 días.
- [ ] **Compresión Columnar**: Datos analíticos almacenados en Parquet o ORC con compresión Snappy o ZSTD.

## 3. Red y Transferencia (*Egress*)

- [ ] **Caché en el Borde (Edge / CDN)**: Activos estáticos, imágenes y respuestas públicas cacheadas en Cloudflare/CloudFront/Fastly para evitar costos de transferencia desde la nube de origen.
- [ ] **Comunicaciones Intra-Región**: Tráfico entre servicios de backend y bases de datos mantenido dentro de la misma región / VPC peering sin atravesar Internet público.

## 4. Presupuestos y Gobernanza

- [ ] **Alertas de Presupuesto**: Configurada alerta de presupuesto al 50%, 80% y 100% de la previsión mensual con notificación a canal de ingeniería.
- [ ] **Etiquetado de Costes (*Cost Allocation Tags*)**: Todos los recursos etiquetados con `Environment`, `Service` y `Owner`.
