---
name: explain-codebase
description: Explica en lenguaje claro, sin modificar archivos, cómo está organizado el repositorio - carpetas, modelos, flujo cliente-servidor y dependencias críticas. Usar cuando alguien quiere entender el código. No usar para documentación formal (docs-architecture-agent) ni guía de bienvenida (onboarding).
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
