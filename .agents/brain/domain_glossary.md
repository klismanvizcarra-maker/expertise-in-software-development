# Glosario del Dominio e Invariantes de Negocio (Domain Glossary)

> **Propósito**: Definir el lenguaje ubicuo (*Ubiquitous Language*) y las reglas infranqueables del negocio para evitar inconsistencias conceptuales o alucinaciones.

---

## 1. Definición de Entidades Clave

| Concepto de Negocio | Definición Técnica | Relaciones Principales |
| :--- | :--- | :--- |
| **Cuenta / Usuario** | Sujeto autenticado en la plataforma | Posee roles, perfiles y permisos |
| **Sesión** | Token de acceso emitido con expiración fija | Pertenece a un usuario y dispositivo |

---

## 2. Invariantes de Negocio (Reglas Inviolables)

1. **Invariante 1**: Ninguna entidad puede transicionar a un estado terminal sin pasar por la fase de aprobación o validación correspondiente.
2. **Invariante 2**: Los identificadores únicos principales (UUID / IDs) deben ser inmutables a lo largo de todo el ciclo de vida del registro.
3. **Invariante 3**: Toda operación con impacto financiero o de permisos debe dejar una traza inmutable en la bitácora de auditoría.
