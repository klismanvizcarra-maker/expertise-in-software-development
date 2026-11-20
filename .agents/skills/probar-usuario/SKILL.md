---
name: probar-usuario
description: Inicia una sesión interactiva de pruebas de usuario (UAT) sobre una pantalla o tarea en revisión - levanta el entorno local, recorre los flujos simulando interacción humana real, captura evidencias de problemas de UX o funcionalidad y gestiona el bucle de rechazo y re-verificación con task.sh reject hasta la aprobación final. Usar cuando una funcionalidad de usuario esté lista para validarse en navegador, antes de cerrar una tarea de interfaz o al investigar problemas de usabilidad percibida. No usar para auditorías de código o seguridad OWASP (qa-review) ni para suites E2E automáticas (e2e-testing).
---

# /probar-usuario — Sesión Interactiva de Pruebas de Usuario (UAT)

Esta skill de flujo ejecuta una sesión de pruebas exploratorias interactuando directamente con la aplicación como un usuario humano. Asume el rol de `user-testing-agent`.

---

## Pasos

1. **Identificar el Objeto de Prueba**:
   - Determina la tarea activa en revisión (`TASK-XXX`) o la pantalla/flujo indicado por el usuario.
   - Lee los Criterios de Aceptación y las rutas involucradas en `GLOBAL_STATE.md`.

2. **Levantar el Entorno**:
   - Comprueba que la aplicación esté corriendo localmente (ej. `npm run dev` o servidor backend/frontend).
   - Verifica que el puerto local responda 200 OK.

3. **Ejecutar el Recorrido Exploratorio (UAT Loop)**:
   - Navega interactivamente por las pantallas principales usando las herramientas de navegador disponibles.
   - Aplica pruebas caóticas: dobles clics rápidos, entradas no válidas, redimensionamiento de ventana a formato móvil (390px de ancho).
   - Evalúa la claridad de los textos, botones y estados de espera.

4. **Documentar y Emitir Veredicto**:
   - Si la prueba encuentra fallos funcionales, bloqueos visuales o textos truncados:
     - Redacta el reporte usando `.agents/templates/uat_bug_report_template.md`.
     - Ejecuta `./.agents/scripts/task.sh reject TASK-XXX "<descripción del fallo y pasos>"`.
     - Informa al especialista para su corrección.
   - Si la prueba es satisfactoria:
     - Documenta el visto bueno de usuario en la entrega para dar paso a la revisión de `qa-security-agent`.

---

## Checklist

- [ ] Servidor local verificado y operativo antes de iniciar la sesión de prueba.
- [ ] Recorrido exploratorio completado en vista de escritorio y vista móvil.
- [ ] Se probaron al menos 3 casos límite de comportamiento humano (doble clic, campos vacíos, cancelación).
- [ ] Todo fallo encontrado documentado con pasos de reproducción claros del 1 al N.
- [ ] Si hubo rechazos previos, se re-verificó el flujo exacto tras la corrección del especialista.

---

## Prohibido

- Prohibido dar por buena una pantalla sin haberla abierto e interactuado con sus controles.
- Prohibido rechazar una tarea con mensajes ambiguos que no permitan al desarrollador reproducir el problema.
- Prohibido saltarse el paso de re-verificación cuando una tarea vuelve de un rechazo previo.
