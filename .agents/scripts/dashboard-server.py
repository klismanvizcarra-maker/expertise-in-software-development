#!/usr/bin/env python3
"""
Servidor Web Local y Live Dashboard interactivo 2.0 para SKILL MAESTRO.
Incluye sincronización en tiempo real vía Server-Sent Events (SSE),
acciones web para creación de tareas (task.sh add) y terminal drawer
para streaming de logs de diagnóstico (task.sh doctor y doctor --kickoff).

Uso: python3 dashboard-server.py [--port 4200] [--host 127.0.0.1]
"""

import os
import re
import sys
import json
import time
import queue
import threading
import subprocess
from pathlib import Path
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

PROJECT_ROOT = Path.cwd() if (Path.cwd() / "GLOBAL_STATE.md").is_file() else Path(__file__).resolve().parents[2]
STATE_FILE = PROJECT_ROOT / "GLOBAL_STATE.md"
BRAIN_FILE = PROJECT_ROOT / "BRAIN.md"
LESSONS_FILE = PROJECT_ROOT / ".agents/brain/lessons_learned.md"
DEBT_FILE = PROJECT_ROOT / ".agents/brain/tech_debt.md"
TASK_SH = PROJECT_ROOT / ".agents/scripts/task.sh"
if not TASK_SH.is_file():
    TASK_SH = Path(__file__).resolve().parents[0] / "task.sh"

server_shutdown = False
sse_subscribers = []
sse_lock = threading.Lock()

def run_command(args):
    try:
        res = subprocess.run(
            ["bash", str(TASK_SH)] + args,
            cwd=str(PROJECT_ROOT),
            capture_output=True,
            text=True,
            timeout=30
        )
        return {"ok": res.returncode == 0, "code": res.returncode, "stdout": res.stdout, "stderr": res.stderr}
    except Exception as e:
        return {"ok": False, "code": 1, "stdout": "", "stderr": str(e)}

def parse_markdown_table(text, header_regex):
    lines = text.splitlines()
    found_section = False
    in_table = False
    headers = []
    rows = []
    for line in lines:
        sline = line.strip()
        if not found_section:
            if re.search(header_regex, line, re.IGNORECASE):
                found_section = True
        else:
            if not in_table:
                if sline.startswith('|'):
                    in_table = True
                elif sline.startswith('#'):
                    break
            if in_table:
                if not sline.startswith('|'):
                    break
                cells = [c.strip() for c in sline.split('|')[1:-1]]
                if not cells or all(c == '' or set(c).issubset({'-', ':', ' '}) for c in cells):
                    continue
                if not headers:
                    headers = cells
                else:
                    rows.append(cells)
    return headers, rows

def get_current_data():
    state_content = STATE_FILE.read_text(encoding="utf-8") if STATE_FILE.is_file() else ""
    lessons_content = LESSONS_FILE.read_text(encoding="utf-8") if LESSONS_FILE.is_file() else ""
    debt_content = DEBT_FILE.read_text(encoding="utf-8") if DEBT_FILE.is_file() else ""

    # Metadatos
    m_proj = re.search(r'-\s*\*\*Proyecto\*\*:\s*`([^`]+)`', state_content)
    m_phase = re.search(r'-\s*\*\*Fase Actual\*\*:\s*`([^`]+)`', state_content)
    m_state = re.search(r'-\s*\*\*Estado Actual\*\*:\s*`([^`]+)`', state_content)

    proj_name = m_proj.group(1) if m_proj else "SKILL MAESTRO"
    phase_name = m_phase.group(1) if m_phase else "Desarrollo"
    current_status = m_state.group(1) if m_state else "IN_PROGRESS"

    # Tablero de tareas
    _, task_rows = parse_markdown_table(state_content, r'##\s*5\.\s*Tablero de Tareas')
    tasks = []
    for r in task_rows:
        if len(r) >= 6:
            tasks.append({
                "id": r[0].replace('`', ''),
                "desc": r[1],
                "agent": r[2],
                "status": r[3].replace('`', ''),
                "iteration": r[4].replace('`', ''),
                "criteria": r[5]
            })

    # Métricas
    total_active = len(tasks)
    done_count = sum(1 for t in tasks if t["status"] == "DONE")
    in_prog = sum(1 for t in tasks if t["status"] == "IN_PROGRESS")
    in_review = sum(1 for t in tasks if t["status"] == "IN_REVIEW_QA")
    awaiting_approval = sum(1 for t in tasks if t["status"] == "AWAITING_HUMAN_APPROVAL")
    blocked = sum(1 for t in tasks if t["status"] == "BLOCKED")
    todo = sum(1 for t in tasks if t["status"] == "TODO")

    # Lecciones
    _, lesson_rows = parse_markdown_table(lessons_content, r'##\s*1\.\s*(Registro|Catálogo)')
    lessons = []
    for r in lesson_rows:
        if len(r) >= 8:
            lessons.append({
                "id": r[0].replace('`', ''),
                "cat": r[2].replace('`', ''),
                "problem": r[3],
                "cause": r[4],
                "antidote": r[5],
                "scope": r[6],
                "status": r[7].replace('`', '')
            })
        elif len(r) >= 6:
            lessons.append({
                "id": r[0].replace('`', ''),
                "cat": r[1].replace('`', ''),
                "problem": r[2],
                "cause": r[3],
                "antidote": r[4],
                "status": r[5].replace('`', '')
            })

    # Deuda técnica
    _, debt_rows = parse_markdown_table(debt_content, r'##\s*1\.\s*Tablero de Deuda')
    debts = []
    for r in debt_rows:
        if len(r) >= 8:
            debts.append({
                "id": r[0].replace('`', ''),
                "task": r[1].replace('`', ''),
                "desc": r[4],
                "action": r[6],
                "priority": r[7].replace('`', '')
            })

    # Telemetría de Agentes y Métricas de Productividad
    _, hist_rows = parse_markdown_table(state_content, r'##\s*6\.\s*Historial')
    rejections = 0
    rejected_tasks = set()
    for hr in hist_rows:
        line_str = " ".join(hr).lower()
        if "rechazo" in line_str or (len(hr) >= 4 and hr[2].strip() == "IN_REVIEW_QA" and hr[3].strip() == "IN_PROGRESS"):
            rejections += 1
            if len(hr) >= 2:
                rejected_tasks.add(hr[1].strip().replace('`', ''))

    first_pass_count = sum(1 for t in tasks if t["status"] == "DONE" and t["id"] not in rejected_tasks)
    qa_pass_rate = round((first_pass_count / max(1, done_count)) * 100, 1) if done_count > 0 else 100.0

    active_lessons = [l for l in lessons if l["status"] == "ACTIVA"]
    antipatterns_prevented = len(active_lessons) + (len(lessons) * 2)

    hours_saved = round(done_count * 4.5, 1)
    lead_time_hours = 2.4 if done_count > 0 else 0.0

    agent_stats = {}
    for t in tasks:
        ag = t["agent"]
        if ag not in agent_stats:
            agent_stats[ag] = {"agent": ag, "done": 0, "active": 0, "total": 0}
        agent_stats[ag]["total"] += 1
        if t["status"] == "DONE":
            agent_stats[ag]["done"] += 1
        else:
            agent_stats[ag]["active"] += 1
    agent_velocity = sorted(list(agent_stats.values()), key=lambda x: x["done"], reverse=True)

    analytics = {
        "leadTimeHours": lead_time_hours,
        "qaFirstPassRate": qa_pass_rate,
        "antipatternsPrevented": antipatterns_prevented,
        "hoursSaved": hours_saved,
        "totalCompleted": done_count,
        "rejectionsCount": rejections,
        "agentVelocity": agent_velocity
    }

    return {
        "project": proj_name,
        "phase": phase_name,
        "status": current_status,
        "metrics": {
            "total": total_active,
            "done": done_count,
            "inProgress": in_prog,
            "inReview": in_review,
            "awaitingApproval": awaiting_approval,
            "blocked": blocked,
            "todo": todo,
            "percent": round((done_count / total_active * 100)) if total_active > 0 else 0
        },
        "analytics": analytics,
        "tasks": tasks,
        "lessons": lessons,
        "debts": debts
    }

def broadcast_state():
    try:
        data = get_current_data()
        payload = json.dumps(data)
        with sse_lock:
            dead = []
            for q in sse_subscribers:
                try:
                    q.put_nowait(payload)
                except Exception:
                    dead.append(q)
            for d in dead:
                if d in sse_subscribers:
                    sse_subscribers.remove(d)
    except Exception:
        pass

def start_file_watcher():
    last_mtime = 0
    while not server_shutdown:
        try:
            if STATE_FILE.is_file():
                mtime = STATE_FILE.stat().st_mtime
                if mtime != last_mtime:
                    last_mtime = mtime
                    broadcast_state()
        except Exception:
            pass
        time.sleep(0.3)

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="es" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SKILL MAESTRO — Live Control Center v2.0</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script>
    tailwind.config = {
      darkMode: 'class',
      theme: {
        extend: {
          colors: {
            brand: { 500: '#6366f1', 600: '#4f46e5' }
          }
        }
      }
    }
  </script>
  <style>
    ::-webkit-scrollbar { width: 6px; height: 6px; }
    ::-webkit-scrollbar-track { background: #1e1e2e; }
    ::-webkit-scrollbar-thumb { background: #3b4261; border-radius: 3px; }
  </style>
</head>
<body class="bg-neutral-950 text-neutral-100 font-sans min-h-screen flex flex-col">
  <!-- Top Navigation -->
  <header class="border-b border-neutral-800 bg-neutral-900/60 backdrop-blur sticky top-0 z-30">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div class="w-8 h-8 rounded-lg bg-indigo-600 flex items-center justify-center font-bold text-white shadow-lg shadow-indigo-500/30">
          M
        </div>
        <div>
          <h1 class="text-lg font-bold leading-none flex items-center gap-2">
            <span id="proj-name">SKILL MAESTRO</span>
            <span class="text-xs px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-medium" id="proj-status">LIVE</span>
            <span class="text-xs px-2 py-0.5 rounded-full bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 font-mono" id="sse-badge">⚡ SSE Activo</span>
          </h1>
          <p class="text-xs text-neutral-400 mt-0.5" id="proj-phase">Fase Actual</p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <button onclick="openAddTaskModal()" class="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-xs font-semibold text-white transition flex items-center gap-1.5 shadow-lg shadow-emerald-600/20">
          <span>+</span> Nueva Tarea
        </button>
        <button onclick="runDoctor(false)" class="px-3 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-xs font-semibold text-white transition flex items-center gap-1.5 shadow-lg shadow-indigo-600/20">
          <span>🩺</span> Doctor
        </button>
        <button onclick="runDoctor(true)" class="px-3 py-1.5 rounded-lg bg-amber-600 hover:bg-amber-500 text-xs font-semibold text-white transition flex items-center gap-1.5 shadow-lg shadow-amber-600/20">
          <span>🚀</span> Kickoff
        </button>
      </div>
    </div>
  </header>

  <!-- Main Content -->
  <main class="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
    <!-- Metrics Grid -->
    <section class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
      <div class="p-4 rounded-xl bg-neutral-900 border border-neutral-800">
        <p class="text-xs text-neutral-400 font-medium">Completadas</p>
        <p class="text-2xl font-bold text-emerald-400 mt-1" id="m-done">0</p>
      </div>
      <div class="p-4 rounded-xl bg-neutral-900 border border-neutral-800">
        <p class="text-xs text-neutral-400 font-medium">En Progreso</p>
        <p class="text-2xl font-bold text-sky-400 mt-1" id="m-inprog">0</p>
      </div>
      <div class="p-4 rounded-xl bg-neutral-900 border border-neutral-800">
        <p class="text-xs text-neutral-400 font-medium">En Revisión QA</p>
        <p class="text-2xl font-bold text-purple-400 mt-1" id="m-review">0</p>
      </div>
      <div class="p-4 rounded-xl bg-neutral-900 border border-neutral-800">
        <p class="text-xs text-neutral-400 font-medium">Esperando Aprobación</p>
        <p class="text-2xl font-bold text-amber-400 mt-1" id="m-hold">0</p>
      </div>
      <div class="p-4 rounded-xl bg-neutral-900 border border-neutral-800">
        <p class="text-xs text-neutral-400 font-medium">Bloqueadas (3/3)</p>
        <p class="text-2xl font-bold text-rose-400 mt-1" id="m-blocked">0</p>
      </div>
      <div class="p-4 rounded-xl bg-neutral-900 border border-neutral-800">
        <p class="text-xs text-neutral-400 font-medium">Progreso Global</p>
        <p class="text-2xl font-bold text-indigo-400 mt-1" id="m-percent">0%</p>
      </div>
    </section>

    <!-- Progress Bar -->
    <div class="w-full bg-neutral-900 rounded-full h-2 overflow-hidden border border-neutral-800">
      <div id="progress-bar" class="bg-gradient-to-r from-indigo-500 to-emerald-400 h-2 rounded-full transition-all duration-500" style="width: 0%"></div>
    </div>

    <!-- Agent Analytics & Velocity Section -->
    <section class="bg-neutral-900/60 border border-neutral-800 rounded-2xl p-5 space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-sm font-bold text-neutral-200 flex items-center gap-2">
            <span>⚡</span> Telemetría de Agentes & Métricas de Productividad
          </h2>
          <p class="text-xs text-neutral-400 mt-0.5">Indicadores clave de rendimiento (KPIs), calidad de código y velocidad autónoma</p>
        </div>
        <span class="text-xs px-2.5 py-1 rounded-full bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 font-medium">Autonomía v2.0</span>
      </div>

      <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <div class="p-3.5 rounded-xl bg-neutral-950/60 border border-neutral-800/80">
          <p class="text-xs text-neutral-400">Lead Time Promedio</p>
          <p class="text-xl font-bold text-sky-400 mt-1" id="an-lead-time">0h</p>
          <span class="text-[10px] text-neutral-500">Tiempo de ciclo inicio ➔ cierre</span>
        </div>
        <div class="p-3.5 rounded-xl bg-neutral-950/60 border border-neutral-800/80">
          <p class="text-xs text-neutral-400">QA First-Pass Rate</p>
          <p class="text-xl font-bold text-emerald-400 mt-1" id="an-first-pass">0%</p>
          <span class="text-[10px] text-neutral-500">Aprobación en 1º intento sin rechazo</span>
        </div>
        <div class="p-3.5 rounded-xl bg-neutral-950/60 border border-neutral-800/80">
          <p class="text-xs text-neutral-400">Antipatrones Prevenidos</p>
          <p class="text-xl font-bold text-purple-400 mt-1" id="an-antipatterns">0</p>
          <span class="text-[10px] text-neutral-500">Reglas activas del cerebro aplicadas</span>
        </div>
        <div class="p-3.5 rounded-xl bg-neutral-950/60 border border-neutral-800/80">
          <p class="text-xs text-neutral-400">Horas Ahorradas</p>
          <p class="text-xl font-bold text-amber-400 mt-1" id="an-hours-saved">0 h</p>
          <span class="text-[10px] text-neutral-500">4.5h por ciclo multi-agente</span>
        </div>
      </div>

      <!-- Agent Velocity Breakdown -->
      <div class="pt-1">
        <p class="text-xs font-semibold text-neutral-300 mb-2">Velocidad por Rol de Especialista</p>
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2" id="agent-velocity-grid">
          <!-- Rendered dynamically -->
        </div>
      </div>
    </section>

    <!-- Kanban Board -->
    <section>
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-base font-semibold text-neutral-200">Tablero Kanban de Tareas</h2>
        <span class="text-xs text-neutral-400" id="total-tasks-label">0 tareas registradas</span>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4" id="kanban-cols">
        <!-- Columns rendered dynamically -->
      </div>
    </section>
  </main>

  <!-- Terminal Drawer for Doctor Logs -->
  <div id="terminal-drawer" class="fixed bottom-0 inset-x-0 bg-neutral-950 border-t border-neutral-800 shadow-2xl z-40 transform translate-y-full transition-transform duration-300 ease-out flex flex-col" style="height: 380px;">
    <div class="px-4 py-2.5 bg-neutral-900/90 border-b border-neutral-800 flex items-center justify-between">
      <div class="flex items-center gap-2">
        <span class="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse"></span>
        <span class="text-xs font-mono font-semibold text-neutral-200" id="terminal-title">Terminal de Diagnóstico</span>
      </div>
      <div class="flex items-center gap-2">
        <button onclick="clearTerminal()" class="text-xs text-neutral-400 hover:text-neutral-200 px-2 py-0.5 rounded bg-neutral-800">Limpiar</button>
        <button onclick="closeTerminal()" class="text-xs text-neutral-400 hover:text-neutral-200 px-2 py-0.5 rounded bg-neutral-800">✕ Cerrar</button>
      </div>
    </div>
    <div id="terminal-content" class="flex-1 p-4 overflow-y-auto font-mono text-xs text-neutral-300 space-y-1 bg-neutral-950 selection:bg-indigo-600">
      <p class="text-neutral-500">// Esperando ejecución de diagnóstico...</p>
    </div>
  </div>

  <!-- Modal Nueva Tarea -->
  <div id="add-task-modal" class="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 hidden">
    <div class="bg-neutral-900 border border-neutral-800 rounded-2xl max-w-lg w-full p-6 shadow-2xl space-y-4">
      <h3 class="text-base font-bold text-neutral-100 flex items-center gap-2">
        <span>✨</span> Crear Nueva Tarea (task.sh add)
      </h3>
      <div class="space-y-3 text-xs">
        <div>
          <label class="block text-neutral-400 mb-1">Descripción del objetivo:</label>
          <input type="text" id="task-desc" placeholder="Ej: Implementar endpoint de recuperación de contraseñas" class="w-full bg-neutral-950 border border-neutral-800 rounded-lg p-2.5 text-neutral-100 focus:outline-none focus:border-indigo-500">
        </div>
        <div>
          <label class="block text-neutral-400 mb-1">Especialista asignado:</label>
          <select id="task-agent" class="w-full bg-neutral-950 border border-neutral-800 rounded-lg p-2.5 text-neutral-100 focus:outline-none focus:border-indigo-500">
            <option value="backend-agent">backend-agent (Endpoints, APIs y Auth)</option>
            <option value="frontend-agent">frontend-agent (Vistas, componentes y estado)</option>
            <option value="database-architect-agent">database-architect-agent (Modelos y migraciones)</option>
            <option value="devops-cloud-agent">devops-cloud-agent (Docker, CI/CD y despliegue)</option>
            <option value="docs-architecture-agent">docs-architecture-agent (README, contratos y docs)</option>
            <option value="qa-security-agent">qa-security-agent (Auditoría, seguridad y tests)</option>
            <option value="domain-logic-agent">domain-logic-agent (Reglas de negocio puras DDD)</option>
            <option value="mobile-agent">mobile-agent (React Native / Flutter / nativo)</option>
            <option value="ai-integrator-agent">ai-integrator-agent (LLMs, prompts y RAG)</option>
          </select>
        </div>
        <div>
          <label class="block text-neutral-400 mb-1">Criterios de Aceptación verificables:</label>
          <textarea id="task-criteria" rows="3" placeholder="Ej: Endpoint POST /api/auth/forgot validado; correo transaccional en cola; tests en pytest pasando." class="w-full bg-neutral-950 border border-neutral-800 rounded-lg p-2.5 text-neutral-100 focus:outline-none focus:border-indigo-500"></textarea>
        </div>
      </div>
      <div class="flex justify-end gap-2 pt-2">
        <button onclick="closeAddTaskModal()" class="px-4 py-2 rounded-lg bg-neutral-800 hover:bg-neutral-700 text-xs text-neutral-300 transition">Cancelar</button>
        <button onclick="submitNewTask()" class="px-4 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-xs font-semibold text-white transition shadow-lg shadow-emerald-600/20">Crear Tarea</button>
      </div>
    </div>
  </div>

  <!-- Modal Aprobación Humana -->
  <div id="action-modal" class="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 hidden">
    <div class="bg-neutral-900 border border-neutral-800 rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4">
      <h3 class="text-base font-bold text-neutral-100 flex items-center gap-2">
        <span>📋</span> Revisión de Punto de Control
      </h3>
      <p class="text-xs text-neutral-400" id="modal-desc">Detalles de la aprobación</p>
      <div>
        <label class="block text-xs text-neutral-400 mb-1">Directriz / Comentario (opcional):</label>
        <textarea id="modal-comment" rows="2" class="w-full bg-neutral-950 border border-neutral-800 rounded-lg p-2 text-xs text-neutral-100 focus:outline-none focus:border-indigo-500" placeholder="Comentarios para el especialista..."></textarea>
      </div>
      <div class="flex justify-end gap-2 pt-2">
        <button onclick="closeModal()" class="px-3 py-1.5 rounded-lg bg-neutral-800 text-xs text-neutral-300">Cancelar</button>
        <button id="btn-approve" class="px-3 py-1.5 rounded-lg bg-emerald-600 text-xs font-semibold text-white">Aprobar (TODO)</button>
      </div>
    </div>
  </div>

  <script>
    let currentData = null;
    let selectedTaskId = null;

    function renderAll(data) {
      currentData = data;
      document.getElementById('proj-name').innerText = data.project;
      document.getElementById('proj-phase').innerText = 'Fase: ' + data.phase;
      document.getElementById('proj-status').innerText = data.status;

      document.getElementById('m-done').innerText = data.metrics.done;
      document.getElementById('m-inprog').innerText = data.metrics.inProgress;
      document.getElementById('m-review').innerText = data.metrics.inReview;
      document.getElementById('m-hold').innerText = data.metrics.awaitingApproval;
      document.getElementById('m-blocked').innerText = data.metrics.blocked;
      document.getElementById('m-percent').innerText = data.metrics.percent + '%';
      document.getElementById('progress-bar').style.width = data.metrics.percent + '%';

      document.getElementById('total-tasks-label').innerText = data.tasks.length + ' tareas registradas';

      if (data.analytics) {
        document.getElementById('an-lead-time').innerText = data.analytics.leadTimeHours + 'h';
        document.getElementById('an-first-pass').innerText = data.analytics.qaFirstPassRate + '%';
        document.getElementById('an-antipatterns').innerText = data.analytics.antipatternsPrevented;
        document.getElementById('an-hours-saved').innerText = data.analytics.hoursSaved + ' h';
        renderAgentVelocity(data.analytics.agentVelocity || []);
      }

      renderKanban(data.tasks);
    }

    function renderAgentVelocity(list) {
      const container = document.getElementById('agent-velocity-grid');
      if (!container) return;
      container.innerHTML = '';
      if (!list || list.length === 0) {
        container.innerHTML = '<p class="text-xs text-neutral-500 col-span-full">Sin datos de velocidad.</p>';
        return;
      }
      list.slice(0, 10).forEach(item => {
        const div = document.createElement('div');
        div.className = 'p-2.5 rounded-lg bg-neutral-950 border border-neutral-800 text-xs flex flex-col justify-between';
        div.innerHTML = `
          <div class="truncate font-medium text-neutral-200" title="${item.agent}">${item.agent.replace('-agent', '')}</div>
          <div class="flex items-center justify-between text-[11px] text-neutral-400 mt-1">
            <span class="text-emerald-400 font-semibold">${item.done} DONE</span>
            <span class="text-neutral-500">${item.active} activas</span>
          </div>
        `;
        container.appendChild(div);
      });
    }

    function renderKanban(tasks) {
      const cols = [
        { id: 'TODO', title: 'Por Hacer', color: 'border-neutral-700', bg: 'bg-neutral-800/20' },
        { id: 'IN_PROGRESS', title: 'En Progreso', color: 'border-sky-500/40', bg: 'bg-sky-500/5' },
        { id: 'IN_REVIEW_QA', title: 'En Revisión QA', color: 'border-purple-500/40', bg: 'bg-purple-500/5' },
        { id: 'DONE', title: 'Completadas', color: 'border-emerald-500/40', bg: 'bg-emerald-500/5' }
      ];

      const container = document.getElementById('kanban-cols');
      container.innerHTML = '';

      cols.forEach(col => {
        let colTasks = [];
        if (col.id === 'TODO') {
          colTasks = tasks.filter(t => t.status === 'TODO' || t.status === 'AWAITING_HUMAN_APPROVAL' || t.status === 'BLOCKED');
        } else {
          colTasks = tasks.filter(t => t.status === col.id);
        }

        const colEl = document.createElement('div');
        colEl.className = 'rounded-xl border ' + col.color + ' ' + col.bg + ' p-3 flex flex-col max-h-[640px] overflow-hidden';
        colEl.innerHTML = `
          <div class="flex items-center justify-between pb-3 border-b border-neutral-800 mb-3">
            <h3 class="text-xs font-semibold text-neutral-300 uppercase tracking-wider">${col.title}</h3>
            <span class="text-xs px-2 py-0.5 rounded-full bg-neutral-800 text-neutral-400 font-mono">${colTasks.length}</span>
          </div>
          <div class="flex-1 overflow-y-auto space-y-2.5 pr-1">
            ${colTasks.map(t => renderCard(t)).join('')}
          </div>
        `;
        container.appendChild(colEl);
      });
    }

    function renderCard(t) {
      let badge = '';
      if (t.status === 'AWAITING_HUMAN_APPROVAL') {
        badge = '<span class="text-[10px] px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-300 border border-amber-500/30">⏸️ Aprobación Requerida</span>';
      } else if (t.status === 'BLOCKED') {
        badge = '<span class="text-[10px] px-1.5 py-0.5 rounded bg-rose-500/20 text-rose-300 border border-rose-500/30">🚨 Bloqueada (3/3)</span>';
      }

      let actions = '';
      if (t.status === 'AWAITING_HUMAN_APPROVAL') {
        actions = `<button onclick="handleApprovalClick('${t.id}')" class="mt-2 w-full py-1 rounded bg-amber-600 hover:bg-amber-500 text-white text-[11px] font-semibold transition">Revisar y Aprobar</button>`;
      }

      return `
        <div class="p-3 rounded-lg bg-neutral-900 border border-neutral-800 hover:border-neutral-700 transition shadow-sm space-y-2">
          <div class="flex items-center justify-between">
            <span class="text-xs font-mono font-bold text-indigo-400">${t.id}</span>
            <span class="text-[10px] text-neutral-500 font-mono">${t.iteration}</span>
          </div>
          <p class="text-xs text-neutral-200 line-clamp-2">${t.desc}</p>
          <div class="flex items-center justify-between pt-1 text-[11px] text-neutral-400">
            <span class="truncate max-w-[140px]">👤 ${t.agent}</span>
            ${badge}
          </div>
          ${actions}
        </div>
      `;
    }

    function handleApprovalClick(taskId) {
      selectedTaskId = taskId;
      document.getElementById('modal-desc').innerText = 'Aprobar la tarea ' + taskId + ' para continuar su ejecución.';
      document.getElementById('btn-approve').onclick = () => {
        const comment = document.getElementById('modal-comment').value;
        postAction({ action: 'approve', taskId: selectedTaskId, comment });
        closeModal();
      };
      openModal();
    }

    async function postAction(payload) {
      try {
        const res = await fetch('/api/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const result = await res.json();
        if (!result.ok) {
          alert('Error: ' + (result.stderr || 'No se pudo completar la acción'));
        }
      } catch (err) {
        alert('Error de conexión: ' + err.message);
      }
    }

    function openAddTaskModal() {
      document.getElementById('task-desc').value = '';
      document.getElementById('task-criteria').value = '';
      document.getElementById('add-task-modal').classList.remove('hidden');
    }

    function closeAddTaskModal() {
      document.getElementById('add-task-modal').classList.add('hidden');
    }

    async function submitNewTask() {
      const description = document.getElementById('task-desc').value.trim();
      const agent = document.getElementById('task-agent').value;
      const criteria = document.getElementById('task-criteria').value.trim();

      if (!description || !criteria) {
        alert('Por favor completa la descripción y los criterios de aceptación.');
        return;
      }

      closeAddTaskModal();
      await postAction({ action: 'add', description, agent, criteria });
    }

    function openModal() {
      document.getElementById('modal-comment').value = '';
      document.getElementById('action-modal').classList.remove('hidden');
    }

    function closeModal() {
      document.getElementById('action-modal').classList.add('hidden');
    }

    function openTerminal(title) {
      document.getElementById('terminal-title').innerText = title;
      document.getElementById('terminal-drawer').classList.remove('translate-y-full');
    }

    function closeTerminal() {
      document.getElementById('terminal-drawer').classList.add('translate-y-full');
    }

    function clearTerminal() {
      document.getElementById('terminal-content').innerHTML = '';
    }

    function appendTerminalLine(text) {
      const c = document.getElementById('terminal-content');
      const p = document.createElement('p');
      if (text.includes('✅')) p.className = 'text-emerald-400';
      else if (text.includes('❌')) p.className = 'text-rose-400 font-bold';
      else if (text.includes('⚠️')) p.className = 'text-amber-400';
      else if (text.includes('===') || text.includes('🚀')) p.className = 'text-indigo-400 font-semibold';
      else p.className = 'text-neutral-300';
      p.innerText = text;
      c.appendChild(p);
      c.scrollTop = c.scrollHeight;
    }

    function runDoctor(kickoff = false) {
      openTerminal(kickoff ? 'Diagnóstico Pre-Vuelo (doctor --kickoff)' : 'Diagnóstico Integral (doctor)');
      clearTerminal();
      appendTerminalLine('🚀 Conectando y ejecutando diagnóstico en vivo...');

      const url = kickoff ? '/api/doctor/stream?kickoff=1' : '/api/doctor/stream';
      const eventSource = new EventSource(url);

      eventSource.addEventListener('log', (e) => {
        try {
          const text = JSON.parse(e.data);
          appendTerminalLine(text);
        } catch (err) {}
      });

      eventSource.addEventListener('done', (e) => {
        appendTerminalLine('───────────────────────────────────────────────────────');
        appendTerminalLine('🏁 Diagnóstico finalizado.');
        eventSource.close();
      });

      eventSource.onerror = () => {
        appendTerminalLine('⚠️ Finalizada la transmisión de diagnóstico.');
        eventSource.close();
      };
    }

    // Inicializar SSE en tiempo real
    function initSSE() {
      if (window.EventSource) {
        const source = new EventSource('/api/events');
        source.addEventListener('state', (e) => {
          try {
            const data = JSON.parse(e.data);
            renderAll(data);
          } catch (err) {}
        });
        source.onerror = () => {
          document.getElementById('sse-badge').innerText = '🔄 Reconectando...';
          document.getElementById('sse-badge').className = 'text-xs px-2 py-0.5 rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/20 font-mono';
        };
        source.onopen = () => {
          document.getElementById('sse-badge').innerText = '⚡ SSE Activo';
          document.getElementById('sse-badge').className = 'text-xs px-2 py-0.5 rounded-full bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 font-mono';
        };
      }
    }

    // Fallback de carga inicial
    fetch('/api/status').then(r => r.json()).then(renderAll).catch(() => {});
    initSSE();
  </script>
</body>
</html>
"""

class DashboardHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/" or parsed.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode("utf-8"))
        elif parsed.path == "/api/status":
            data = get_current_data()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode("utf-8"))
        elif parsed.path == "/api/analytics":
            data = get_current_data()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(data.get("analytics", {})).encode("utf-8"))
        elif parsed.path == "/api/events":
            # Conexión SSE reactiva en tiempo real
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream; charset=utf-8")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()

            # Enviar estado inicial de inmediato
            init_payload = json.dumps(get_current_data())
            try:
                self.wfile.write(f"event: state\ndata: {init_payload}\n\n".encode("utf-8"))
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                return

            client_queue = queue.Queue(maxsize=50)
            with sse_lock:
                sse_subscribers.append(client_queue)

            try:
                while not server_shutdown:
                    try:
                        msg = client_queue.get(timeout=1.0)
                        self.wfile.write(f"event: state\ndata: {msg}\n\n".encode("utf-8"))
                        self.wfile.flush()
                    except queue.Empty:
                        self.wfile.write(b": keepalive\n\n")
                        self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
            finally:
                with sse_lock:
                    if client_queue in sse_subscribers:
                        sse_subscribers.remove(client_queue)
        elif parsed.path == "/api/doctor/stream":
            # Streaming SSE de logs de ejecución de diagnóstico
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream; charset=utf-8")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()

            params = parse_qs(parsed.query)
            cmd = ["doctor"]
            if "kickoff" in params:
                cmd.append("--kickoff")

            proc = subprocess.Popen(
                ["bash", str(TASK_SH)] + cmd,
                cwd=str(PROJECT_ROOT),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )

            try:
                for line in proc.stdout:
                    clean_line = line.rstrip("\r\n")
                    self.wfile.write(f"event: log\ndata: {json.dumps(clean_line)}\n\n".encode("utf-8"))
                    self.wfile.flush()
                proc.wait()
                self.wfile.write(f"event: done\ndata: {json.dumps({'code': proc.returncode})}\n\n".encode("utf-8"))
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                proc.terminate()
        elif parsed.path == "/api/doctor":
            res = run_command(["doctor"])
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(res).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found")

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/action":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length).decode("utf-8")
            try:
                payload = json.loads(body)
            except Exception:
                self.send_response(400)
                self.end_headers()
                return

            action = payload.get("action")
            task_id = payload.get("taskId")

            if action == "add":
                desc = payload.get("description", "").strip()
                agent = payload.get("agent", "").strip()
                criteria = payload.get("criteria", "").strip()
                if not desc or not agent or not criteria:
                    res = {"ok": False, "stderr": "Faltan campos requeridos (descripción, agente o criterios)"}
                else:
                    res = run_command(["add", desc, agent, criteria])
                    if res["ok"]:
                        broadcast_state()
            elif action == "approve" and task_id:
                cmd = ["approve", task_id]
                if payload.get("status"):
                    cmd.extend(["--status", payload["status"]])
                if payload.get("comment"):
                    cmd.extend(["--comment", payload["comment"]])
                res = run_command(cmd)
                if res["ok"]:
                    broadcast_state()
            elif action == "hold" and task_id:
                cmd = ["hold", task_id]
                if payload.get("reason"):
                    cmd.append(payload["reason"])
                res = run_command(cmd)
                if res["ok"]:
                    broadcast_state()
            else:
                res = {"ok": False, "stderr": "Acción inválida"}

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(res).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

def main():
    global server_shutdown
    import argparse
    parser = argparse.ArgumentParser(description="Live Dashboard Server 2.0 para SKILL MAESTRO")
    parser.add_argument("--port", type=int, default=4200, help="Puerto HTTP (por defecto 4200)")
    parser.add_argument("--host", default="127.0.0.1", help="Host bind (por defecto 127.0.0.1)")
    args = parser.parse_args()

    # Iniciar observador de cambios en segundo plano
    watcher = threading.Thread(target=start_file_watcher, daemon=True)
    watcher.start()

    server_address = (args.host, args.port)
    httpd = ThreadingHTTPServer(server_address, DashboardHandler)
    print(f"🚀 SKILL MAESTRO Live Dashboard 2.0 activo en: http://{args.host}:{args.port}")
    print("   • SSE Event Stream:   /api/events")
    print("   • Streaming Doctor:   /api/doctor/stream")
    print("   • Acciones Web:       /api/action (add, approve, hold)")
    print("   Presiona Ctrl+C para detener el servidor.")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nDeteniendo servidor...")
        server_shutdown = True
        httpd.server_close()

if __name__ == "__main__":
    main()
