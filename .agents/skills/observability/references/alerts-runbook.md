# Alertas Accionables y Runbooks

## Principios
- **Alerta sobre síntomas**, lo que nota el usuario: errores, lentitud, operaciones que no se completan. Las causas (CPU, memoria, disco) van a paneles, salvo que anticipen un fallo seguro (disco al 95 %).
- **Toda alerta exige acción**. Si salta y nadie hace nada, se ajusta o se elimina.
- **Duración mínima**: el umbral debe mantenerse unos minutos para no alertar por picos sueltos.
- **Una alerta, un runbook**. Sin runbook no se activa.

## Alertas de partida

| Alerta | Condición (ejemplo) | Severidad |
| :--- | :--- | :--- |
| Tasa de error alta | errores 5xx > 2 % de las peticiones durante 5 min | Página (urgente) |
| Latencia degradada | p95 > 1 s durante 10 min en rutas principales | Ticket o página según impacto |
| Servicio no listo | `/readyz` falla durante 2 min | Página |
| Negocio parado | `orders_created_total` sin incrementos en 30 min en horario de actividad | Página |
| Cola atascada | mensajes pendientes crecen durante 15 min o el más antiguo supera 10 min | Ticket |
| Certificado TLS | caduca en menos de 14 días | Ticket |

Los umbrales se ajustan con datos reales tras las primeras semanas, y las alertas por porcentaje exigen un mínimo de tráfico (p. ej. 50 peticiones en la ventana) para no saltar con dos errores de madrugada. Si hay SLO definidos (p. ej. 99,5 % de peticiones correctas al mes), alerta por consumo del presupuesto de error en varias ventanas (rápida: 1 h y 5 min; lenta: 6 h y 30 min) en lugar de umbrales fijos.

## Plantilla de runbook

```markdown
# Runbook: <nombre de la alerta>

**Qué significa**: <qué está viendo el usuario>.
**Cómo confirmarlo**: <panel, consulta de logs con el filtro exacto, comando>.
**Causas habituales**:
1. <causa> → <cómo se reconoce> → <qué hacer>
2. ...
**Mitigación inmediata**: <rollback de la última versión, desactivar el feature flag, escalar réplicas>.
**Escalar a**: <persona o equipo> si no se resuelve en <N> minutos.
**Después**: registrar el incidente; si la causa fue un defecto, abrir `/bugfix` y su lección con `/aprender`.
```

Guarda los runbooks en `docs/runbooks/` y enlaza cada uno desde la definición de su alerta. Los redacta quien define la alerta (backend o devops) y los mantiene `docs-architecture-agent`, dueño de `docs/` (`AGENTS.md` §8).
