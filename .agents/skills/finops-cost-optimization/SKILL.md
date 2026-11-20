---
name: finops-cost-optimization
description: Audita y optimiza el consumo de recursos y costes en infraestructura cloud (FinOps) - dimensionamiento de memoria y CPU en serverless/contenedores, optimización de consultas en data warehouses (BigQuery/Athena/Snowflake), políticas de ciclo de vida en almacenamiento de objetos (S3/GCS), reducción de transferencia de red (egress) y presupuestos de alerta. Usar al preparar el paso a producción para auditar costes, al optimizar consultas analíticas pesadas o al dimensionar funciones serverless y contenedores. No usar para métricas de latencia de aplicación (web-performance), logs y alertas RED (observability) ni para infraestructura o pipelines de build sin foco en costes (devops-cloud-agent).
---

# FinOps & Cost Optimization

Especialista en eficiencia financiera de infraestructura cloud, optimización de recursos, reducción de desperdicio computacional y arquitectura rentable (*cost-aware architecture*).

## Principios y Áreas de Optimización

1. **Computación Serverless y Contenedores**:
   - Ajuste empírico de memoria y CPU basado en perfiles reales de ejecución.
   - Eliminación de concurrencia reservada innecesaria y fijación de timeouts defensivos para evitar bloqueos costosos.
   - Escala a cero para entornos de pruebas, staging y workers no críticos.

2. **Bases de Datos y Almacenes Analíticos**:
   - Prohibición de escaneos completos (*full scans*) en motores con cobro por datos leídos (BigQuery, Athena).
   - Uso sistemático de particionamiento, clustering y compresión columnar (Parquet).
   - Detección de instancias sobredimensionadas en bases de datos relacionales (*rightsizing* de CPU e IOPS).

3. **Almacenamiento de Objetos y Ciclos de Vida**:
   - Reglas de transición automática a capas de almacenamiento frío (*Glacier / Archive*) y expiración de datos temporales.
   - Purga de artefactos huérfanos, snapshots obsoletos e imágenes de contenedor no referenciadas.

4. **Transferencia de Red (Egress)**:
   - Maximización de cacheo en CDN para absorber tráfico antes de llegar a la infraestructura de origen.
   - Enrutamiento interno dentro de la misma zona de disponibilidad para evitar tarifas de cruce de red.

Consulta la guía técnica detallada en [references/finops-checklist.md](references/finops-checklist.md).

## Protocolo de Trabajo

1. **Auditoría de recursos actuales**:
   - Revisa las configuraciones de `serverless.yml`, `Dockerfile`, Kubernetes manifests o plantillas IaC (Terraform).
   - Identifica parámetros sobredimensionados (ej. memoria asignada vs utilizada en el percentil 95).
2. **Optimización de consultas y almacenamiento**:
   - Analiza planes de ejecución (`EXPLAIN`) de consultas analíticas o ETLs con alto consumo de cómputo.
   - Añade filtros de partición y proyección explícita de campos.
3. **Establecer umbrales y alertas**:
   - Configura alertas de gasto inusual y etiquetas de asignación de costos (*Cost Allocation Tags*).

## Prohibido

- Prohibido degradar la resiliencia o disponibilidad de producción por recortes indiscriminados de capacidad.
- Prohibido optimizar sin medir previamente el impacto y el consumo histórico real.
- Prohibido configurar funciones serverless sin timeout o con valores desproporcionados (ej. 15 minutos en peticiones HTTP).
- Prohibido dejar buckets de almacenamiento de objetos sin políticas de ciclo de vida para datos históricos.

## Checklist antes de `task.sh handoff`

- [ ] Recursos serverless y contenedores dimensionados según percentil 90/95 de consumo real.
- [ ] Timeouts acotados en todas las funciones y llamadas a dependencias.
- [ ] Consultas analíticas optimizadas con particiones y sin `SELECT *`.
- [ ] Políticas de ciclo de vida configuradas en almacenamiento de objetos.
- [ ] Verificada la guía en [references/finops-checklist.md](references/finops-checklist.md).
