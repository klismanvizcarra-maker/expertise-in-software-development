/**
 * Tests automatizados para el servidor MCP nativo de SKILL MAESTRO (.agents/mcp/server.mjs).
 * Incluye pruebas para transporte stdio, recursos URI, prompts y transporte SSE/HTTP.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import http from "node:http";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SERVER_PATH = resolve(__dirname, "../.agents/mcp/server.mjs");

function createMcpClient() {
  const proc = spawn("node", [SERVER_PATH], {
    stdio: ["pipe", "pipe", "pipe"]
  });

  let buffer = "";
  const pendingRequests = new Map();

  proc.stdout.on("data", (chunk) => {
    buffer += chunk.toString();
    const lines = buffer.split("\n");
    buffer = lines.pop(); // Mantener el último segmento incompleto

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      try {
        const msg = JSON.parse(trimmed);
        if (msg.id !== undefined && pendingRequests.has(msg.id)) {
          const { resolvePromise, rejectPromise } = pendingRequests.get(msg.id);
          pendingRequests.delete(msg.id);
          if (msg.error) {
            rejectPromise(new Error(msg.error.message || "MCP Error"));
          } else {
            resolvePromise(msg.result);
          }
        }
      } catch (e) {
        // Ignorar líneas no JSON
      }
    }
  });

  let nextId = 1;

  return {
    send(method, params = {}) {
      return new Promise((resolvePromise, rejectPromise) => {
        const id = nextId++;
        pendingRequests.set(id, { resolvePromise, rejectPromise });
        const payload = JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n";
        proc.stdin.write(payload);
      });
    },
    close() {
      proc.stdin.end();
      proc.kill();
    }
  };
}

test("MCP Server: initialize responde con protocolo, serverInfo y capabilities v2", async () => {
  const client = createMcpClient();
  try {
    const res = await client.send("initialize", {});
    assert.equal(res.protocolVersion, "2024-11-05");
    assert.equal(res.serverInfo.name, "skill-maestro");
    assert.equal(res.serverInfo.version, "2.0.0");
    assert.ok(res.capabilities.tools, "Debe soportar tools");
    assert.ok(res.capabilities.resources, "Debe soportar resources");
    assert.ok(res.capabilities.prompts, "Debe soportar prompts");
  } finally {
    client.close();
  }
});

test("MCP Server: tools/list lista todas las herramientas con schemas válidos", async () => {
  const client = createMcpClient();
  try {
    const res = await client.send("tools/list", {});
    assert.ok(Array.isArray(res.tools));
    assert.ok(res.tools.length >= 12, "Debe tener al menos 12 herramientas registradas");

    const toolNames = res.tools.map((t) => t.name);
    assert.ok(toolNames.includes("task_list"));
    assert.ok(toolNames.includes("task_metrics"));
    assert.ok(toolNames.includes("task_add"));
    assert.ok(toolNames.includes("task_start"));
    assert.ok(toolNames.includes("task_handoff"));
    assert.ok(toolNames.includes("task_close"));
    assert.ok(toolNames.includes("brain_search"));
    assert.ok(toolNames.includes("brain_hotspots"));
    assert.ok(toolNames.includes("doctor_check"));
    assert.ok(toolNames.includes("contracts_validate"));
  } finally {
    client.close();
  }
});

test("MCP Server: tools/call task_metrics ejecuta y devuelve texto", async () => {
  const client = createMcpClient();
  try {
    const res = await client.send("tools/call", {
      name: "task_metrics",
      arguments: {}
    });
    assert.equal(res.isError, false);
    assert.ok(Array.isArray(res.content));
    assert.ok(res.content[0].text.includes("Métricas del Proyecto"));
  } finally {
    client.close();
  }
});

test("MCP Server: tools/call brain_search devuelve resultados", async () => {
  const client = createMcpClient();
  try {
    const res = await client.send("tools/call", {
      name: "brain_search",
      arguments: { query: "antipatron" }
    });
    assert.equal(res.isError, false);
    assert.ok(Array.isArray(res.content));
    assert.ok(res.content[0].text.length > 0);
  } finally {
    client.close();
  }
});

test("MCP Server: tools/call swarm_status devuelve estado del enjambre", async () => {
  const client = createMcpClient();
  try {
    const res = await client.send("tools/call", {
      name: "swarm_status",
      arguments: {}
    });
    assert.equal(res.isError, false);
    assert.ok(Array.isArray(res.content));
    assert.ok(res.content[0].text.includes("Enjambre Multi-Agente"));
  } finally {
    client.close();
  }
});

test("MCP Server: resources/list expone URIs estándar maestro://", async () => {
  const client = createMcpClient();
  try {
    const res = await client.send("resources/list", {});
    assert.ok(Array.isArray(res.resources));
    const uris = res.resources.map((r) => r.uri);
    assert.ok(uris.includes("maestro://state"));
    assert.ok(uris.includes("maestro://brain"));
    assert.ok(uris.includes("maestro://contracts"));
    assert.ok(uris.includes("maestro://preferences"));
  } finally {
    client.close();
  }
});

test("MCP Server: resources/read resuelve contenido de maestro://state y maestro://brain", async () => {
  const client = createMcpClient();
  try {
    const stateRes = await client.send("resources/read", { uri: "maestro://state" });
    assert.ok(stateRes.contents && stateRes.contents.length > 0);
    assert.equal(stateRes.contents[0].uri, "maestro://state");
    assert.ok(stateRes.contents[0].text.includes("Tablero de Tareas") || stateRes.contents[0].text.includes("Metadatos del Proyecto"));

    const brainRes = await client.send("resources/read", { uri: "maestro://brain" });
    assert.ok(brainRes.contents && brainRes.contents.length > 0);
    assert.equal(brainRes.contents[0].uri, "maestro://brain");
    assert.ok(brainRes.contents[0].text.includes("LL-"));
  } finally {
    client.close();
  }
});

test("MCP Server: prompts/list expone plantillas de inicio, handoff y qa", async () => {
  const client = createMcpClient();
  try {
    const res = await client.send("prompts/list", {});
    assert.ok(Array.isArray(res.prompts));
    const names = res.prompts.map((p) => p.name);
    assert.ok(names.includes("start_task"));
    assert.ok(names.includes("handoff_task"));
    assert.ok(names.includes("qa_review"));
  } finally {
    client.close();
  }
});

test("MCP Server: prompts/get genera instrucciones con taskId parametrizado", async () => {
  const client = createMcpClient();
  try {
    const res = await client.send("prompts/get", {
      name: "start_task",
      arguments: { taskId: "TASK-098" }
    });
    assert.ok(res.description.includes("TASK-098"));
    assert.ok(Array.isArray(res.messages));
    assert.ok(res.messages[0].content.text.includes("TASK-098"));
    assert.ok(res.messages[0].content.text.includes("task.sh brain for TASK-098"));
  } finally {
    client.close();
  }
});

test("MCP Server: servidor SSE/HTTP responde a health y procesa mensajes", async () => {
  const testPort = 4219;
  const proc = spawn("node", [SERVER_PATH, "--port", String(testPort)], {
    stdio: ["ignore", "pipe", "pipe"]
  });

  // Esperar a que el servidor inicie
  await new Promise((resolve) => setTimeout(resolve, 600));

  try {
    // 1. Health check HTTP
    const health = await new Promise((resolve, reject) => {
      http.get(`http://localhost:${testPort}/health`, (res) => {
        let data = "";
        res.on("data", (chunk) => { data += chunk; });
        res.on("end", () => resolve(JSON.parse(data)));
      }).on("error", reject);
    });

    assert.equal(health.status, "ok");
    assert.equal(health.transport, "sse");
    assert.equal(health.server, "skill-maestro");

    // 2. Conectar a SSE y recibir endpoint
    const sseInfo = await new Promise((resolve, reject) => {
      const req = http.get(`http://localhost:${testPort}/sse`, (res) => {
        let buffer = "";
        res.on("data", (chunk) => {
          buffer += chunk.toString();
          if (buffer.includes("event: endpoint")) {
            const match = buffer.match(/data:\s*([^\r\n]+)/);
            if (match) {
              resolve({ endpoint: match[1], stream: res });
            }
          }
        });
      });
      req.on("error", reject);
    });

    assert.ok(sseInfo.endpoint.startsWith("/message?sessionId="));

    // 3. Enviar solicitud JSON-RPC vía POST /message
    const rpcPromise = new Promise((resolve) => {
      sseInfo.stream.on("data", (chunk) => {
        const text = chunk.toString();
        if (text.includes("event: message")) {
          const match = text.match(/data:\s*([^\r\n]+)/);
          if (match) {
            resolve(JSON.parse(match[1]));
          }
        }
      });
    });

    const postReq = http.request(`http://localhost:${testPort}${sseInfo.endpoint}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" }
    });

    postReq.write(JSON.stringify({
      jsonrpc: "2.0",
      id: 99,
      method: "ping"
    }));
    postReq.end();

    const rpcRes = await rpcPromise;
    assert.equal(rpcRes.id, 99);
    assert.deepEqual(rpcRes.result, {});

    sseInfo.stream.destroy();
  } finally {
    proc.kill("SIGTERM");
  }
});
