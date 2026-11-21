/**
 * Tests automatizados para el servidor MCP nativo de SKILL MAESTRO (.agents/mcp/server.mjs).
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

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

test("MCP Server: initialize responde con protocolo y serverInfo", async () => {
  const client = createMcpClient();
  try {
    const res = await client.send("initialize", {});
    assert.equal(res.protocolVersion, "2024-11-05");
    assert.equal(res.serverInfo.name, "skill-maestro");
    assert.equal(res.serverInfo.version, "2.0.0");
    assert.ok(res.capabilities.tools);
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

test("MCP Server: tools/call herramienta inexistente devuelve isError true", async () => {
  const client = createMcpClient();
  try {
    const res = await client.send("tools/call", {
      name: "herramienta_fantasma",
      arguments: {}
    });
    assert.equal(res.isError, true);
    assert.ok(res.content[0].text.includes("Herramienta desconocida"));
  } finally {
    client.close();
  }
});
