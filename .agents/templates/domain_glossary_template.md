# Glosario del Dominio e Invariantes de Negocio (Domain Glossary)

> **Propósito**: Lenguaje ubicuo e invariantes inquebrantables del dominio para garantizar consistencia terminológica en todo el equipo de agentes.

---

## 1. Términos del Dominio

| Término | Definición Precisa | Contexto / Módulo |
| :--- | :--- | :--- |
| **Usuario** | Entidad o actor principal registrado en el sistema | Auth / Usuarios |

---

## 2. Invariantes y Reglas de Negocio Inquebrantables

1. **Inmutabilidad de Registros Críticos**: Las transacciones financieras y logs de auditoría no admiten edición destructiva ni eliminación física.
2. **Autorización Obligatoria**: Toda mutación de estado exige verificación explícita de permisos y pertenencia de recursos (prevención IDOR).
