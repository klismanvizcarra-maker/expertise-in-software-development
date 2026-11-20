---
name: explain-codebase
description: Explora y explica interactivamente en lenguaje humano claro la estructura, flujo de datos, dominios y responsabilidades del repositorio - responde qué hace cada carpeta, dónde se definen los modelos, cómo se comunican cliente y servidor y cuáles son las dependencias críticas sin modificar archivos. Usar cuando una persona nueva pida entender el código, al explorar un área desconocida del repositorio o al explicar el impacto de un cambio transversal. No usar para redactar documentación formal OpenAPI o ADRs (usar docs-architecture-agent) ni para redactar la guía de onboarding permanente (usar onboarding).
---

# /explain-codebase — Explicación Guiada del Repositorio para Humanos

Esta skill de flujo permite a cualquier persona solicitar un recorrido guiado y explicaciones pedagógicas de cualquier sección o de la totalidad del código fuente, traduciendo la complejidad técnica a conceptos accesibles.

---

## Pasos

1. **Delimitar el Alcance de la Consulta**:
   - Pregunta o identifica si el humano desea un recorrido general del proyecto o de un submódulo concreto (ej. flujo de autenticación, modelo de datos, pasarela de pagos).

2. **Mapeo de Rutas y Responsabilidades**:
   - Inspecciona las carpetas clave del proyecto según el stack (`src/app`, `server/api`, `database/`, etc.).
   - Muestra un árbol simplificado con el propósito de cada directorio.

3. **Trazado de Flujo de Datos**:
   - Explica el recorrido de una petición típica: desde que el usuario interactúa en la interfaz, pasando por el controlador, el servicio de negocio, la consulta a base de datos y la respuesta.
   - Apóyate en diagramas Mermaid de secuencia o flujo cuando facilite la comprensión.

4. **Advertencias de Complejidad y Reglas del Cerebro**:
   - Señala las áreas sensibles del código (hotspots de lecciones aprendidas de `BRAIN.md`).
   - Advierte sobre trampas conocidas del stack antes de que el humano modifique archivos.

---

## Checklist

- [ ] Explicación redactada en lenguaje pedagógico, claro y adaptado al nivel del usuario.
- [ ] Árbol de directorios principal contextualizado con la función real de cada carpeta.
- [ ] Flujo de datos end-to-end explicado de forma secuencial.
- [ ] Zonas sensibles y lecciones del cerebro (`BRAIN.md`) advertidas al usuario.

---

## Prohibido

- Prohibido modificar archivos de código fuente durante una sesión de explicación (modo solo lectura).
- Prohibido responder con listas genéricas de archivos sin explicar la relación entre ellos.
- Prohibido usar tecnicismos innecesarios sin definirlos previamente.
