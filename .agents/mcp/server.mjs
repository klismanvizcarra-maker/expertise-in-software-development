#!/usr/bin/env node
/**
 * Servidor MCP Nativo de SKILL MAESTRO v2 (Model Context Protocol).
 *
 * Expone herramientas de ciclo de vida de tareas, consulta del cerebro persistente,
 * validación de contratos, recursos URI (maestro://...) y prompts preconfigurados.
 *
 * Soporta dos transportes:
 * 1. stdio: Modo predeterminado (newline-delimited JSON-RPC 2.0).
 * 2. HTTP / Server-Sent Events (SSE): Activado con --port <N> o --sse (protocolo MCP 2024-11-05).
 *
 * Sin dependencias externas: 100% nativo con Node.js 18+.
 */

import { spawn } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createInterface } from "node:readline";
import { readFileSync, existsSync } from "node:fs";
import { createServer } from "node:http";
import { randomUUID } from "node:crypto";

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
    inputSchema: { type: "object", properties: {}, required: [] }
  },
  {
    name: "task_metrics",
    description: "Devuelve las métricas consolidadas de avance, tareas completadas y salud de QA.",
    inputSchema: { type: "object", properties: {}, required: [] }
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
    inputSchema: { type: "object", properties: {}, required: [] }
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
    inputSchema: { type: "object", properties: {}, required: [] }
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
    inputSchema: { type: "object", properties: {}, required: [] }
  }
];

/**
 * Catálogo de Recursos MCP (Resources URI).
 */
const RESOURCES = [
  {
    uri: "maestro://state",
    name: "Estado Global del Proyecto",
    description: "Contenido completo de GLOBAL_STATE.md con metadatos del proyecto, fase actual, contratos activos y tablero Kanban.",
    mimeType: "text/markdown"
  },
  {
    uri: "maestro://brain",
    name: "Cerebro y Lecciones Aprendidas",
    description: "Contenido de .agents/brain/lessons_learned.md con lecciones aprendidas activas, causas raíz y antídotos.",
    mimeType: "text/markdown"
  },
  {
    uri: "maestro://contracts",
    name: "Contratos de Integración Inter-Agente",
    description: "Especificación formal de endpoints, DTOs y validaciones de contratos en contracts.json.",
    mimeType: "application/json"
  },
  {
    uri: "maestro://preferences",
    name: "Preferencias Vinculantes de Usuario",
    description: "Directrices de estilo, tipado y diseño declaradas en .agents/brain/preferences.md.",
    mimeType: "text/markdown"
  }
];

/**
 * Catálogo de Prompts Preconfigurados MCP.
 */
const PROMPTS = [
  {
    name: "start_task",
    description: "Prepara el contexto y directrices para iniciar el desarrollo de una tarea TASK-XXX.",
    arguments: [
      { name: "taskId", description: "Identificador de la tarea (ej. TASK-001)", required: true }
    ]
  },
  {
    name: "handoff_task",
    description: "Estructura el checklist y comando de hand-off para entregar una tarea a QA.",
    arguments: [
      { name: "taskId", description: "Identificador de la tarea completada", required: true }
    ]
  },
  {
    name: "qa_review",
    description: "Genera el protocolo de verificación independiente y plantilla de informe de revisión para QA.",
    arguments: [
      { name: "taskId", description: "Identificador de la tarea en revisión", required: true }
    ]
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
 * Resuelve y lee el contenido de un Resource URI.
 */
function handleResourceRead(uri) {
  let filePath = null;
  let mimeType = "text/plain";

  switch (uri) {
    case "maestro://state":
      filePath = resolve(PROJECT_ROOT, "GLOBAL_STATE.md");
      mimeType = "text/markdown";
      break;
    case "maestro://brain":
      filePath = resolve(PROJECT_ROOT, ".agents/brain/lessons_learned.md");
      mimeType = "text/markdown";
      break;
    case "maestro://contracts":
      filePath = resolve(PROJECT_ROOT, "contracts.json");
      mimeType = "application/json";
      break;
    case "maestro://preferences":
      filePath = resolve(PROJECT_ROOT, ".agents/brain/preferences.md");
      mimeType = "text/markdown";
      break;
    default:
      throw new Error(`Recurso URI no soportado: ${uri}`);
  }

  let text = "";
  if (existsSync(filePath)) {
    text = readFileSync(filePath, "utf-8");
  } else {
    text = uri === "maestro://contracts" ? "{}" : `[Archivo no encontrado: ${filePath}]`;
  }

  return {
    contents: [
      {
        uri,
        mimeType,
        text
      }
    ]
  };
}

/**
 * Resuelve y genera el contenido de un Prompt preconfigurado.
 */
function handlePromptGet(name, args = {}) {
  const taskId = args.taskId || "TASK-XXX";

  switch (name) {
    case "start_task":
      return {
        description: `Directrices de inicio para la tarea ${taskId}`,
        messages: [
          {
            role: "user",
            content: {
              type: "text",
              text: `Estás asignado a la tarea ${taskId}. Sigue estrictamente este protocolo de inicio:
1. Inspecciona lecciones previas y deuda técnica relevante: \`./.agents/scripts/task.sh brain for ${taskId}\`.
2. Revisa las preferencias vinculantes del usuario en \`.agents/brain/preferences.md\`.
3. Inicia la tarea y crea su rama Git dedicada: \`./.agents/scripts/task.sh start ${taskId}\`.
4. Antes de modificar cualquier archivo, verifica permisos y lecciones: \`./.agents/scripts/task.sh check <archivos>\`.
5. Implementa el código cumpliendo exactamente todos los Criterios de Aceptación.`
            }
          }
        ]
      };

    case "handoff_task":
      return {
        description: `Checklist y directrices de entrega formal para la tarea ${taskId}`,
        messages: [
          {
            role: "user",
            content: {
              type: "text",
              text: `Vas a realizar la entrega de la tarea ${taskId} al revisor de QA:
1. Revisa que el diff sea limpio y exacto: \`./.agents/scripts/task.sh diff ${taskId} --stat\`.
2. Asegura que todos los tests unitarios y de integración pasen en verde.
3. Si la tarea incluye endpoints o contratos, valida la especificación: \`./.agents/scripts/task.sh contracts validate\`.
4. Ejecuta el hand-off formal con los comandos de verificación reproducibles:
   \`./.agents/scripts/task.sh handoff ${taskId} qa-security-agent --verify "<comando-1>" --verify "<comando-2>"\`.
5. Recuerda: nunca cierres tu propia tarea; espera el veredicto independiente de QA.`
            }
          }
        ]
      };

    case "qa_review":
      return {
        description: `Protocolo de revisión independiente de QA para la tarea ${taskId}`,
        messages: [
          {
            role: "user",
            content: {
              type: "text",
              text: `Como qa-security-agent, realiza la revisión independiente de la tarea ${taskId}:
1. Comprueba el diff completo de la rama: \`./.agents/scripts/task.sh diff ${taskId}\`.
2. Ejecuta tú mismo los comandos de verificación del especialista indicados en el historial de GLOBAL_STATE.md.
3. Audita la seguridad (inyecciones, exposición de secretos, OWASP) y contratos inter-agente.
4. Si pasa todos los criterios: aprueba y cierra con \`./.agents/scripts/task.sh close ${taskId} [--lesson LL-ID | --no-lesson "<motivo>"]\`.
5. Si falla algún criterio o introduce defectos: rechaza con \`./.agents/scripts/task.sh reject ${taskId} "<motivo>"\`. (Límite 3 iteraciones).`
            }
          }
        ]
      };

    default:
      throw new Error(`Prompt desconocido: ${name}`);
  }
}

/**
 * Procesador central de peticiones JSON-RPC 2.0.
 */
async function processJsonRpcRequest(request) {
  const { id, method, params } = request;

  // Notificaciones sin ID
  if (id === undefined || id === null) {
    if (method === "notifications/initialized") {
      // Cliente listo
    }
    return null;
  }

  try {
    switch (method) {
      case "initialize": {
        return {
          jsonrpc: "2.0",
          id,
          result: {
            protocolVersion: PROTOCOL_VERSION,
            capabilities: {
              tools: {},
              resources: {},
              prompts: {}
            },
            serverInfo: {
              name: SERVER_NAME,
              version: SERVER_VERSION
            }
          }
        };
      }

      case "ping": {
        return { jsonrpc: "2.0", id, result: {} };
      }

      case "tools/list": {
        return { jsonrpc: "2.0", id, result: { tools: TOOLS } };
      }

      case "tools/call": {
        const toolName = params?.name;
        const toolArgs = params?.arguments || {};
        const result = await handleToolCall(toolName, toolArgs);
        return { jsonrpc: "2.0", id, result };
      }

      case "resources/list": {
        return { jsonrpc: "2.0", id, result: { resources: RESOURCES } };
      }

      case "resources/read": {
        const uri = params?.uri;
        if (!uri) {
          return {
            jsonrpc: "2.0",
            id,
            error: { code: -32602, message: "Parámetro 'uri' requerido para resources/read" }
          };
        }
        const result = handleResourceRead(uri);
        return { jsonrpc: "2.0", id, result };
      }

      case "prompts/list": {
        return { jsonrpc: "2.0", id, result: { prompts: PROMPTS } };
      }

      case "prompts/get": {
        const promptName = params?.name;
        const promptArgs = params?.arguments || {};
        if (!promptName) {
          return {
            jsonrpc: "2.0",
            id,
            error: { code: -32602, message: "Parámetro 'name' requerido para prompts/get" }
          };
        }
        const result = handlePromptGet(promptName, promptArgs);
        return { jsonrpc: "2.0", id, result };
      }

      default: {
        return {
          jsonrpc: "2.0",
          id,
          error: { code: -32601, message: `Método no encontrado: ${method}` }
        };
      }
    }
  } catch (err) {
    return {
      jsonrpc: "2.0",
      id,
      error: { code: -32603, message: `Error interno: ${err.message}` }
    };
  }
}

/**
 * Modo Servidor HTTP / Server-Sent Events (SSE).
 */
function startSseServer(port) {
  const sseClients = new Map();

  const server = createServer(async (req, res) => {
    // CORS headers
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

    const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);

    // Endpoint Health Check
    if (url.pathname === "/health" || url.pathname === "/") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({
        status: "ok",
        server: SERVER_NAME,
        version: SERVER_VERSION,
        mcp: PROTOCOL_VERSION,
        transport: "sse",
        activeClients: sseClients.size
      }));
      return;
    }

    // Handshake SSE: GET /sse
    if (req.method === "GET" && url.pathname === "/sse") {
      const sessionId = randomUUID();
      res.writeHead(200, {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive"
      });

      sseClients.set(sessionId, res);

      // Enviar evento de inicialización de endpoint con sessionId
      res.write(`event: endpoint\r\ndata: /message?sessionId=${sessionId}\r\n\r\n`);

      req.on("close", () => {
        sseClients.delete(sessionId);
      });
      return;
    }

    // Recepción de mensajes JSON-RPC: POST /message?sessionId=...
    if (req.method === "POST" && url.pathname === "/message") {
      const sessionId = url.searchParams.get("sessionId");
      const clientRes = sseClients.get(sessionId);

      let body = "";
      req.on("data", (chunk) => { body += chunk; });
      req.on("end", async () => {
        let request;
        try {
          request = JSON.parse(body);
        } catch (e) {
          res.writeHead(400, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: "Invalid JSON" }));
          return;
        }

        // Procesar solicitud JSON-RPC
        const rpcResponse = await processJsonRpcRequest(request);

        // Responder al cliente HTTP (202 Accepted según spec MCP SSE)
        res.writeHead(202, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ accepted: true }));

        // Emitir respuesta al canal SSE si hay respuesta y cliente activo
        if (rpcResponse && clientRes) {
          clientRes.write(`event: message\r\ndata: ${JSON.stringify(rpcResponse)}\r\n\r\n`);
        }
      });
      return;
    }

    // Ruta no encontrada
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Not found" }));
  });

  server.listen(port, () => {
    console.error(`🚀 Servidor MCP de SKILL MAESTRO v${SERVER_VERSION} activo vía SSE en http://localhost:${port}`);
    console.error(`   - SSE Stream:   http://localhost:${port}/sse`);
    console.error(`   - Health check: http://localhost:${port}/health`);
  });

  return server;
}

/**
 * Modo stdio (predeterminado).
 */
function startStdioServer() {
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
      process.stdout.write(JSON.stringify({ jsonrpc: "2.0", id: null, error: { code: -32700, message: "Parse error" } }) + "\n");
      return;
    }

    const response = await processJsonRpcRequest(request);
    if (response) {
      process.stdout.write(JSON.stringify(response) + "\n");
    }
  });
}

// Punto de entrada: selección de transporte
const args = process.argv.slice(2);
let portArg = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--port" && args[i + 1]) {
    portArg = parseInt(args[i + 1], 10);
    i++;
  } else if (args[i].startsWith("--port=")) {
    portArg = parseInt(args[i].split("=")[1], 10);
  } else if (args[i] === "--sse") {
    portArg = portArg || parseInt(process.env.PORT || "4201", 10);
  }
}

if (portArg) {
  startSseServer(portArg);
} else {
  startStdioServer();
}

// Manejo seguro de terminación
process.on("SIGTERM", () => process.exit(0));
process.on("SIGINT", () => process.exit(0));
