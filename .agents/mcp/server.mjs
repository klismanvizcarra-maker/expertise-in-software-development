#!/usr/bin/env node
/**
 * Servidor MCP Nativo de SKILL MAESTRO (Model Context Protocol).
 *
 * Expone herramientas de ciclo de vida de tareas, consulta del cerebro persistente,
 * validación de contratos y diagnóstico integral directamente a cualquier asistente de IA.
 *
 * Protocolo: JSON-RPC 2.0 sobre stdio (newline-delimited).
 * Sin dependencias externas: funciona directamente con Node.js 18+.
 */

import { spawn } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createInterface } from "node:readline";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(__dirname, "../..");
const TASK_SH = resolve(PROJECT_ROOT, ".agents/scripts/task.sh");

const SERVER_NAME = "skill-maestro";
const SERVER_VERSION = "2.0.0";
const PROTOCOL_VERSION = "2024-11-05";

/**
 * Ejecuta un subcomando de task.sh de forma segura y devuelve { exitCode, stdout, stderr }.
 */
function runTaskScript(args, extraEnv = {}) {
  return new Promise((resolvePromise) => {
    const proc = spawn("bash", [TASK_SH, ...args], {
      cwd: PROJECT_ROOT,
      env: { ...process.env, ...extraEnv },
      stdio: ["ignore", "pipe", "pipe"]
    });

    let stdout = "";
    let stderr = "";

    proc.stdout.on("data", (chunk) => { stdout += chunk.toString(); });
    proc.stderr.on("data", (chunk) => { stderr += chunk.toString(); });

    proc.on("close", (exitCode) => {
      resolvePromise({
        exitCode: exitCode ?? 0,
        stdout: stdout.trim(),
        stderr: stderr.trim()
      });
    });

    proc.on("error", (err) => {
      resolvePromise({
        exitCode: 1,
        stdout: "",
        stderr: err.message
      });
    });
  });
}

/**
 * Definición del catálogo de herramientas MCP.
 */
const TOOLS = [
  {
    name: "task_list",
    description: "Lista el tablero de tareas Kanban actual desde GLOBAL_STATE.md con sus estados y asignaciones.",
    inputSchema: {
      type: "object",
      properties: {},
      required: []
    }
  },
  {
    name: "task_metrics",
    description: "Devuelve las métricas consolidadas de avance, tareas completadas y salud de QA.",
    inputSchema: {
      type: "object",
      properties: {},
      required: []
    }
  },
  {
    name: "task_add",
    description: "Crea una nueva tarea en estado TODO con especialista asignado y criterios de aceptación verificables.",
    inputSchema: {
      type: "object",
      properties: {
        description: { type: "string", description: "Descripción clara del objetivo de la tarea." },
        agent: { type: "string", description: "Skill o rol especialista asignado (ej. backend-agent, frontend-agent)." },
        criteria: { type: "string", description: "Criterios de aceptación verificables y comandos de prueba." }
      },
      required: ["description", "agent", "criteria"]
    }
  },
  {
    name: "task_start",
    description: "Pasa una tarea de TODO a IN_PROGRESS y crea automáticamente su rama Git dedicada.",
    inputSchema: {
      type: "object",
      properties: {
        taskId: { type: "string", description: "Identificador de la tarea (ej. TASK-001)." }
      },
      required: ["taskId"]
    }
  },
  {
    name: "task_hold",
    description: "Pausa una tarea para aprobación humana explícita (AWAITING_HUMAN_APPROVAL).",
    inputSchema: {
      type: "object",
      properties: {
        taskId: { type: "string", description: "Identificador de la tarea." },
        reason: { type: "string", description: "Motivo o decisión que requiere revisión humana." }
      },
      required: ["taskId"]
    }
  },
  {
    name: "task_approve",
    description: "Aprueba y reanuda una tarea pausada en AWAITING_HUMAN_APPROVAL hacia TODO o IN_PROGRESS.",
    inputSchema: {
      type: "object",
      properties: {
        taskId: { type: "string", description: "Identificador de la tarea." },
        status: { type: "string", enum: ["TODO", "IN_PROGRESS"], description: "Estado al que reanudar (por defecto TODO)." },
        comment: { type: "string", description: "Comentario o directriz de aprobación." }
      },
      required: ["taskId"]
    }
  },
  {
    name: "task_handoff",
    description: "Realiza la entrega formal de una tarea completada a QA para revisión independiente (IN_PROGRESS -> IN_REVIEW_QA).",
    inputSchema: {
      type: "object",
      properties: {
        taskId: { type: "string", description: "Identificador de la tarea." },
        reviewer: { type: "string", description: "Revisor independiente asignado (por defecto qa-security-agent)." },
        verifyCommands: {
          type: "array",
          items: { type: "string" },
          description: "Lista de comandos reproducibles para que QA verifique la entrega."
        }
      },
      required: ["taskId"]
    }
  },
  {
    name: "task_reject",
    description: "Rechaza una entrega en revisión de QA (+1 iteración hasta 3/3; a 3/3 escala a BLOCKED).",
    inputSchema: {
      type: "object",
      properties: {
        taskId: { type: "string", description: "Identificador de la tarea." },
        reason: { type: "string", description: "Motivo detallado del rechazo y criterios insatisfechos." }
      },
      required: ["taskId", "reason"]
    }
  },
  {
    name: "task_close",
    description: "Aprueba y cierra una tarea en revisión (IN_REVIEW_QA -> DONE) registrando una lección aprendida o motivo.",
    inputSchema: {
      type: "object",
      properties: {
        taskId: { type: "string", description: "Identificador de la tarea." },
        lessonId: { type: "string", description: "ID de la lección aprendida (ej. LL-001) si corrigió defectos." },
        noLessonReason: { type: "string", description: "Motivo por el que no requirió lección (ej. feature a la primera)." }
      },
      required: ["taskId"]
    }
  },
  {
    name: "brain_search",
    description: "Busca lecciones aprendidas, gotchas técnicos y preferencias vinculantes en el cerebro del proyecto.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Palabras clave o términos a buscar." }
      },
      required: ["query"]
    }
  },
  {
    name: "brain_hotspots",
    description: "Calcula el ranking de riesgo de rutas según concentración de lecciones y reincidencias acumuladas.",
    inputSchema: {
      type: "object",
      properties: {},
      required: []
    }
  },
  {
    name: "brain_lint",
    description: "Audita proactivamente el código contra antipatrones aprendidos con antídotos deterministas (LL-001, LL-007, LL-012, LL-016).",
    inputSchema: {
      type: "object",
      properties: {
        paths: {
          type: "array",
          items: { type: "string" },
          description: "Rutas opcionales de archivos a auditar."
        }
      },
      required: []
    }
  },
  {
    name: "doctor_check",
    description: "Ejecuta el diagnóstico integral del proyecto en 5 etapas (Estado, Cerebro, Lint, Secretos, Skills).",
    inputSchema: {
      type: "object",
      properties: {},
      required: []
    }
  },
  {
    name: "contracts_validate",
    description: "Valida la integridad y coherencia de los contratos de integración inter-agente (contracts.json).",
    inputSchema: {
      type: "object",
      properties: {
        contractPath: { type: "string", description: "Ruta opcional al archivo de contratos (por defecto contracts.json)." }
      },
      required: []
    }
  },
  {
    name: "swarm_status",
    description: "Inspecciona el estado del enjambre multi-agente: agentes activos concurrentes, ramas de trabajo y workspaces aislados.",
    inputSchema: {
      type: "object",
      properties: {},
      required: []
    }
  }
];

/**
 * Enrutador de llamadas a herramientas.
 */
async function handleToolCall(name, args) {
  switch (name) {
    case "swarm_status": {
      const res = await runTaskScript(["swarm", "status"]);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "task_list": {
      const res = await runTaskScript(["list"]);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "task_metrics": {
      const res = await runTaskScript(["metrics"]);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "task_add": {
      const res = await runTaskScript(["add", args.description, args.agent, args.criteria]);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "task_start": {
      const res = await runTaskScript(["start", args.taskId]);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "task_hold": {
      const cmdArgs = ["hold", args.taskId];
      if (args.reason) cmdArgs.push(args.reason);
      const res = await runTaskScript(cmdArgs);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "task_approve": {
      const cmdArgs = ["approve", args.taskId];
      if (args.status) cmdArgs.push("--status", args.status);
      if (args.comment) cmdArgs.push("--comment", args.comment);
      const res = await runTaskScript(cmdArgs);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "task_handoff": {
      const cmdArgs = ["handoff", args.taskId];
      if (args.reviewer) cmdArgs.push(args.reviewer);
      if (Array.isArray(args.verifyCommands)) {
        for (const cmd of args.verifyCommands) {
          cmdArgs.push("--verify", cmd);
        }
      }
      const res = await runTaskScript(cmdArgs);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "task_reject": {
      const res = await runTaskScript(["reject", args.taskId, args.reason]);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "task_close": {
      const cmdArgs = ["close", args.taskId];
      if (args.lessonId) {
        cmdArgs.push("--lesson", args.lessonId);
      } else if (args.noLessonReason) {
        cmdArgs.push("--no-lesson", args.noLessonReason);
      }
      const res = await runTaskScript(cmdArgs);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "brain_search": {
      const res = await runTaskScript(["brain", "search", args.query]);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "brain_hotspots": {
      const res = await runTaskScript(["brain", "hotspots"]);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "brain_lint": {
      const cmdArgs = ["brain", "lint"];
      if (Array.isArray(args.paths) && args.paths.length > 0) {
        cmdArgs.push(...args.paths);
      }
      const res = await runTaskScript(cmdArgs);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "doctor_check": {
      const res = await runTaskScript(["doctor"]);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    case "contracts_validate": {
      const cmdArgs = ["contracts", "validate"];
      if (args.contractPath) cmdArgs.push(args.contractPath);
      const res = await runTaskScript(cmdArgs);
      return { content: [{ type: "text", text: res.stdout || res.stderr }], isError: res.exitCode !== 0 };
    }
    default:
      return {
        content: [{ type: "text", text: `Herramienta desconocida: ${name}` }],
        isError: true
      };
  }
}

/**
 * Bucle principal JSON-RPC sobre stdio.
 */
function sendResponse(id, result, error = null) {
  const msg = { jsonrpc: "2.0", id };
  if (error) {
    msg.error = error;
  } else {
    msg.result = result;
  }
  process.stdout.write(JSON.stringify(msg) + "\n");
}

function sendNotification(method, params = {}) {
  const msg = { jsonrpc: "2.0", method, params };
  process.stdout.write(JSON.stringify(msg) + "\n");
}

const rl = createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

rl.on("line", async (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;

  let request;
  try {
    request = JSON.parse(trimmed);
  } catch (e) {
    sendResponse(null, null, { code: -32700, message: "Parse error" });
    return;
  }

  const { id, method, params } = request;

  // Notificaciones sin id
  if (id === undefined || id === null) {
    if (method === "notifications/initialized") {
      // Servidor listo
    }
    return;
  }

  switch (method) {
    case "initialize": {
      sendResponse(id, {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: {
          tools: {}
        },
        serverInfo: {
          name: SERVER_NAME,
          version: SERVER_VERSION
        }
      });
      break;
    }

    case "ping": {
      sendResponse(id, {});
      break;
    }

    case "tools/list": {
      sendResponse(id, { tools: TOOLS });
      break;
    }

    case "tools/call": {
      const toolName = params?.name;
      const toolArgs = params?.arguments || {};
      try {
        const result = await handleToolCall(toolName, toolArgs);
        sendResponse(id, result);
      } catch (err) {
        sendResponse(id, {
          content: [{ type: "text", text: `Error interno: ${err.message}` }],
          isError: true
        });
      }
      break;
    }

    default: {
      sendResponse(id, null, {
        code: -32601,
        message: `Método no encontrado: ${method}`
      });
      break;
    }
  }
});

// Manejo seguro de terminación
process.on("SIGTERM", () => process.exit(0));
process.on("SIGINT", () => process.exit(0));
