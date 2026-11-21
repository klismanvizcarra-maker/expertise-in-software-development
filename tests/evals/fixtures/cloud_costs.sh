#!/usr/bin/env bash
# Fixture: TASK-003 en curso para finops-cost-optimization: funcion sobredimensionada, logs sin ciclo de vida y consulta analitica sin filtro de particion.
set -euo pipefail
T=./.agents/scripts/task.sh

$T add "Auditoria de costes cloud antes de produccion" "devops-cloud-agent" \
  "infra/functions.json: thumbnail redimensionada segun su consumo medido: memoryMb con al menos un 40 por ciento de margen sobre p95MemoryUsedMb y sin pasar de 1024, y timeoutS entre 2 y 60 acorde a su duracion p95; infra/storage.json: app-logs con regla de ciclo de vida (formato del _doc) que mueve los objetos a una clase mas barata no antes del dia 30 y los borra (expirationDays) no antes de retentionDays; analytics/daily_revenue.sql sin SELECT * (tampoco DISTINCT *), filtrando en el WHERE de la consulta principal por la columna de particion event_date (no basta en GROUP BY, subconsultas ni comentarios) y manteniendo event_type = 'purchase'; docs/finops/report.md con el ahorro mensual de computo de la funcion como importe en USD calculado con docs/pricing.md y la duracion media (avgDurationMs), sin inventar precios; entrega a QA" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p infra analytics docs
cat > infra/functions.json <<'EOF'
{
  "functions": [
    {
      "name": "thumbnail",
      "runtime": "nodejs22.x",
      "memoryMb": 3008,
      "timeoutS": 900,
      "metrics30d": { "invocationsPerMonth": 2000000, "avgDurationMs": 400, "p95DurationMs": 700, "p95MemoryUsedMb": 180 }
    }
  ]
}
EOF

cat > infra/storage.json <<'EOF'
{
  "buckets": [
    {
      "name": "app-logs",
      "sizeGb": 5000,
      "storageClass": "STANDARD",
      "access": "Los logs casi no se leen pasados 30 dias; auditoria exige conservarlos 365 dias",
      "retentionDays": 365,
      "lifecycleRules": []
    }
  ],
  "_doc": "Regla: { \"transitions\": [{ \"days\": N, \"storageClass\": \"STANDARD_IA|GLACIER_IR|GLACIER|DEEP_ARCHIVE\" }], \"expirationDays\": N }"
}
EOF

cat > analytics/daily_revenue.sql <<'EOF'
-- Ingresos de ayer. analytics.events esta particionada por event_date (DATE) y pesa 40 TB.
SELECT *
FROM analytics.events
WHERE event_type = 'purchase';
EOF

cat > docs/pricing.md <<'EOF'
# Precios de referencia (usar solo estos)

- Funciones serverless: 0.0000166667 USD por GB-segundo de computo (memoria en GB x duracion facturada en segundos). Asume que la duracion no cambia al reducir la memoria.
- Peticiones de funciones: 0.20 USD por millon (no cambian con la memoria).
- Almacenamiento: STANDARD 0.023, STANDARD_IA 0.0125, GLACIER_IR 0.004 USD por GB-mes.
EOF

git add -A
$T commit TASK-003 "anadir configuracion inicial de infraestructura" chore >/dev/null
