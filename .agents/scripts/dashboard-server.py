#!/usr/bin/env python3
"""
Servidor Web Local y Live Dashboard interactivo para SKILL MAESTRO.
Uso: python3 dashboard-server.py [--port 4200] [--host 127.0.0.1]
"""

import os
import re
import sys
import json
import subprocess
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

PROJECT_ROOT = Path(__file__).resolve().parents[2]
STATE_FILE = PROJECT_ROOT / "GLOBAL_STATE.md"
BRAIN_FILE = PROJECT_ROOT / "BRAIN.md"
LESSONS_FILE = PROJECT_ROOT / ".agents/brain/lessons_learned.md"
DEBT_FILE = PROJECT_ROOT / ".agents/brain/tech_debt.md"
TASK_SH = PROJECT_ROOT / ".agents/scripts/task.sh"

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
    in_table = False
    headers = []
    rows = []
    for line in lines:
        if not in_table:
            if re.search(header_regex, line, re.IGNORECASE):
                in_table = True
        else:
            if not line.strip().startswith('|'):
                in_table = False
                continue
            cells = [c.strip() for c in line.strip().split('|')[1:-1]]
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
    _, lesson_rows = parse_markdown_table(lessons_content, r'##\s*1\.\s*Catálogo')
    lessons = []
    for r in lesson_rows:
        if len(r) >= 6:
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
        "tasks": tasks,
        "lessons": lessons,
        "debts": debts
    }

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
            brand: { 50: '#eef2ff', 500: '#6366f1', 600: '#4f46e5', 700: '#4338ca' }
          }
        }
      }
    };
  </script>
  <style>
    .glass { background: rgba(30, 41, 59, 0.7); backdrop-filter: blur(12px); border: 1px solid rgba(255,255,255,0.08); }
    .card-glow:hover { box-shadow: 0 0 20px -5px rgba(99, 102, 241, 0.3); border-color: rgba(99, 102, 241, 0.4); }
  </style>
</head>
<body class="bg-slate-950 text-slate-100 min-h-screen font-sans flex flex-col">
  <!-- Header -->
  <header class="glass sticky top-0 z-40 border-b border-slate-800/80 px-6 py-4 flex flex-wrap items-center justify-between gap-4">
    <div class="flex items-center gap-3">
      <div class="w-10 h-10 rounded-xl bg-gradient-to-tr from-brand-600 to-indigo-400 flex items-center justify-center font-black text-xl text-white shadow-lg shadow-brand-500/30">M</div>
      <div>
        <h1 class="font-bold text-lg leading-tight flex items-center gap-2" id="ui-project-title">SKILL MAESTRO <span class="text-xs bg-brand-500/20 text-brand-400 border border-brand-500/30 px-2 py-0.5 rounded-full font-semibold">v2.0 LIVE</span></h1>
        <p class="text-xs text-slate-400" id="ui-phase-title">Cargando fase...</p>
      </div>
    </div>
    
    <!-- Controls & Status -->
    <div class="flex items-center gap-3">
      <div class="flex items-center gap-2 text-xs text-emerald-400 bg-emerald-950/60 border border-emerald-800/50 px-3 py-1.5 rounded-lg">
        <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
        <span>En vivo (Polling activo)</span>
      </div>
      <button onclick="runDoctor()" class="text-xs font-medium bg-slate-800 hover:bg-slate-700 text-slate-200 px-3 py-1.5 rounded-lg border border-slate-700 flex items-center gap-1.5 transition">
        <span>🩺</span> Ejecutar Doctor
      </button>
      <button onclick="fetchData()" class="text-xs font-medium bg-brand-600 hover:bg-brand-500 text-white px-3 py-1.5 rounded-lg shadow-md transition">
        <span>🔄</span> Actualizar
      </button>
    </div>
  </header>

  <!-- Metrics Bar -->
  <section class="max-w-7xl mx-auto w-full px-6 pt-6 grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
    <div class="glass p-4 rounded-xl flex flex-col">
      <span class="text-xs text-slate-400 font-medium">Progreso Global</span>
      <span class="text-2xl font-bold text-brand-400 mt-1" id="m-percent">0%</span>
    </div>
    <div class="glass p-4 rounded-xl flex flex-col">
      <span class="text-xs text-slate-400 font-medium">En Progreso</span>
      <span class="text-2xl font-bold text-blue-400 mt-1" id="m-inprog">0</span>
    </div>
    <div class="glass p-4 rounded-xl flex flex-col">
      <span class="text-xs text-slate-400 font-medium">En Revisión QA</span>
      <span class="text-2xl font-bold text-amber-400 mt-1" id="m-inreview">0</span>
    </div>
    <div class="glass p-4 rounded-xl flex flex-col">
      <span class="text-xs text-slate-400 font-medium">Esperando Aprobación</span>
      <span class="text-2xl font-bold text-purple-400 mt-1" id="m-awaiting">0</span>
    </div>
    <div class="glass p-4 rounded-xl flex flex-col">
      <span class="text-xs text-slate-400 font-medium">Bloqueadas (3/3)</span>
      <span class="text-2xl font-bold text-rose-400 mt-1" id="m-blocked">0</span>
    </div>
    <div class="glass p-4 rounded-xl flex flex-col">
      <span class="text-xs text-slate-400 font-medium">Completadas (DONE)</span>
      <span class="text-2xl font-bold text-emerald-400 mt-1" id="m-done">0</span>
    </div>
  </section>

  <!-- Kanban Board -->
  <main class="max-w-7xl mx-auto w-full px-6 py-6 flex-1">
    <h2 class="text-sm font-semibold uppercase tracking-wider text-slate-400 mb-4 flex items-center gap-2">
      <span>📋 Tablero Kanban de Tareas</span>
      <span class="text-xs bg-slate-800 text-slate-300 px-2 py-0.5 rounded-full" id="task-count-badge">0</span>
    </h2>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4 items-start">
      <!-- TODO -->
      <div class="flex flex-col gap-3 bg-slate-900/40 p-3 rounded-2xl border border-slate-800/60 min-h-[400px]">
        <div class="flex items-center justify-between px-2 text-xs font-bold text-slate-400 uppercase">
          <span>Por Hacer (TODO)</span>
          <span class="w-5 h-5 rounded-full bg-slate-800 flex items-center justify-center" id="col-todo-count">0</span>
        </div>
        <div class="flex flex-col gap-2.5" id="col-todo"></div>
      </div>

      <!-- IN_PROGRESS -->
      <div class="flex flex-col gap-3 bg-slate-900/40 p-3 rounded-2xl border border-slate-800/60 min-h-[400px]">
        <div class="flex items-center justify-between px-2 text-xs font-bold text-blue-400 uppercase">
          <span>En Curso</span>
          <span class="w-5 h-5 rounded-full bg-blue-900/60 flex items-center justify-center text-blue-300" id="col-inprog-count">0</span>
        </div>
        <div class="flex flex-col gap-2.5" id="col-inprog"></div>
      </div>

      <!-- IN_REVIEW_QA -->
      <div class="flex flex-col gap-3 bg-slate-900/40 p-3 rounded-2xl border border-slate-800/60 min-h-[400px]">
        <div class="flex items-center justify-between px-2 text-xs font-bold text-amber-400 uppercase">
          <span>Revisión QA</span>
          <span class="w-5 h-5 rounded-full bg-amber-900/60 flex items-center justify-center text-amber-300" id="col-inreview-count">0</span>
        </div>
        <div class="flex flex-col gap-2.5" id="col-inreview"></div>
      </div>

      <!-- AWAITING_HUMAN_APPROVAL -->
      <div class="flex flex-col gap-3 bg-slate-900/40 p-3 rounded-2xl border border-slate-800/60 min-h-[400px]">
        <div class="flex items-center justify-between px-2 text-xs font-bold text-purple-400 uppercase">
          <span>Aprobación Humana</span>
          <span class="w-5 h-5 rounded-full bg-purple-900/60 flex items-center justify-center text-purple-300" id="col-awaiting-count">0</span>
        </div>
        <div class="flex flex-col gap-2.5" id="col-awaiting"></div>
      </div>

      <!-- DONE -->
      <div class="flex flex-col gap-3 bg-slate-900/40 p-3 rounded-2xl border border-slate-800/60 min-h-[400px]">
        <div class="flex items-center justify-between px-2 text-xs font-bold text-emerald-400 uppercase">
          <span>Completadas (DONE)</span>
          <span class="w-5 h-5 rounded-full bg-emerald-900/60 flex items-center justify-center text-emerald-300" id="col-done-count">0</span>
        </div>
        <div class="flex flex-col gap-2.5 max-h-[600px] overflow-y-auto pr-1" id="col-done"></div>
      </div>
    </div>
  </main>

  <!-- Modal Action Dialog -->
  <div id="action-modal" class="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 hidden flex items-center justify-center p-4">
    <div class="glass p-6 rounded-2xl max-w-md w-full border border-slate-700 shadow-2xl flex flex-col gap-4">
      <h3 class="font-bold text-lg text-white" id="modal-title">Aprobar Tarea</h3>
      <p class="text-xs text-slate-300" id="modal-desc">¿Deseas reanudar esta tarea?</p>
      
      <div id="modal-inputs" class="flex flex-col gap-3">
        <label class="text-xs font-medium text-slate-400">Comentario o Directriz:</label>
        <textarea id="modal-comment" rows="2" class="w-full bg-slate-950 border border-slate-700 rounded-lg p-2.5 text-xs text-slate-200 focus:outline-none focus:border-brand-500"></textarea>
      </div>

      <div class="flex justify-end gap-2 pt-2">
        <button onclick="closeModal()" class="px-4 py-2 text-xs font-medium text-slate-400 hover:text-slate-200">Cancelar</button>
        <button id="modal-confirm-btn" class="px-4 py-2 text-xs font-semibold bg-brand-600 hover:bg-brand-500 text-white rounded-lg shadow-md transition">Confirmar</button>
      </div>
    </div>
  </div>

  <script>
    let activeData = null;

    async function fetchData() {
      try {
        const res = await fetch('/api/status');
        const data = await res.json();
        activeData = data;
        renderDashboard(data);
      } catch (err) {
        console.error("Error al cargar estado:", err);
      }
    }

    function renderDashboard(data) {
      document.getElementById('ui-project-title').innerHTML = `${data.project} <span class="text-xs bg-brand-500/20 text-brand-400 border border-brand-500/30 px-2 py-0.5 rounded-full font-semibold">v2.0 LIVE</span>`;
      document.getElementById('ui-phase-title').textContent = data.phase;

      // Métricas
      document.getElementById('m-percent').textContent = data.metrics.percent + '%';
      document.getElementById('m-inprog').textContent = data.metrics.inProgress;
      document.getElementById('m-inreview').textContent = data.metrics.inReview;
      document.getElementById('m-awaiting').textContent = data.metrics.awaitingApproval;
      document.getElementById('m-blocked').textContent = data.metrics.blocked;
      document.getElementById('m-done').textContent = data.metrics.done;
      document.getElementById('task-count-badge').textContent = data.tasks.length;

      // Limpiar columnas
      const cols = {
        'TODO': document.getElementById('col-todo'),
        'IN_PROGRESS': document.getElementById('col-inprog'),
        'IN_REVIEW_QA': document.getElementById('col-inreview'),
        'AWAITING_HUMAN_APPROVAL': document.getElementById('col-awaiting'),
        'DONE': document.getElementById('col-done')
      };

      Object.values(cols).forEach(el => el.innerHTML = '');

      const counts = { 'TODO': 0, 'IN_PROGRESS': 0, 'IN_REVIEW_QA': 0, 'AWAITING_HUMAN_APPROVAL': 0, 'DONE': 0 };

      data.tasks.forEach(t => {
        const colKey = cols[t.status] ? t.status : 'TODO';
        counts[colKey]++;
        const card = createCard(t);
        cols[colKey].appendChild(card);
      });

      document.getElementById('col-todo-count').textContent = counts['TODO'];
      document.getElementById('col-inprog-count').textContent = counts['IN_PROGRESS'];
      document.getElementById('col-inreview-count').textContent = counts['IN_REVIEW_QA'];
      document.getElementById('col-awaiting-count').textContent = counts['AWAITING_HUMAN_APPROVAL'];
      document.getElementById('col-done-count').textContent = counts['DONE'];
    }

    function createCard(task) {
      const el = document.createElement('div');
      el.className = 'glass card-glow p-3.5 rounded-xl flex flex-col gap-2 transition duration-200 border border-slate-800 text-xs';
      
      let actionButtons = '';
      if (task.status === 'AWAITING_HUMAN_APPROVAL') {
        actionButtons = `
          <div class="flex gap-1.5 pt-1.5 border-t border-slate-800">
            <button onclick="promptApprove('${task.id}')" class="flex-1 bg-emerald-600/80 hover:bg-emerald-500 text-white font-semibold py-1 rounded text-[11px] transition">✓ Aprobar</button>
          </div>
        `;
      } else if (task.status === 'IN_PROGRESS') {
        actionButtons = `
          <div class="flex gap-1.5 pt-1.5 border-t border-slate-800">
            <button onclick="promptHold('${task.id}')" class="flex-1 bg-purple-600/60 hover:bg-purple-500 text-slate-100 font-medium py-1 rounded text-[11px] transition">⏸ Pausar (Hold)</button>
          </div>
        `;
      }

      el.innerHTML = `
        <div class="flex items-center justify-between gap-2">
          <span class="font-mono font-bold text-slate-300 text-[11px] bg-slate-800 px-1.5 py-0.5 rounded">${task.id}</span>
          <span class="text-[10px] text-slate-400 font-medium truncate max-w-[120px]">${task.agent}</span>
        </div>
        <p class="text-slate-200 leading-snug line-clamp-3">${task.desc}</p>
        <div class="flex items-center justify-between text-[10px] text-slate-400 pt-1">
          <span>Iteración: ${task.iteration}</span>
        </div>
        ${actionButtons}
      `;
      return el;
    }

    function promptApprove(taskId) {
      document.getElementById('modal-title').textContent = `Aprobar Tarea ${taskId}`;
      document.getElementById('modal-desc').textContent = `Al aprobar, la tarea saldrá de AWAITING_HUMAN_APPROVAL y se reanudará en TODO o IN_PROGRESS.`;
      document.getElementById('modal-confirm-btn').onclick = async () => {
        const comment = document.getElementById('modal-comment').value;
        closeModal();
        await postAction({ action: 'approve', taskId, status: 'TODO', comment });
      };
      openModal();
    }

    function promptHold(taskId) {
      document.getElementById('modal-title').textContent = `Pausar Tarea ${taskId}`;
      document.getElementById('modal-desc').textContent = `Indica el motivo por el cual requieres pausar esta tarea para aprobación humana.`;
      document.getElementById('modal-confirm-btn').onclick = async () => {
        const reason = document.getElementById('modal-comment').value;
        closeModal();
        await postAction({ action: 'hold', taskId, reason });
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
        fetchData();
      } catch (err) {
        alert('Error de conexión: ' + err.message);
      }
    }

    async function runDoctor() {
      const btn = event.currentTarget;
      btn.disabled = true;
      btn.innerHTML = '<span>⏳</span> Analizando...';
      try {
        const res = await fetch('/api/doctor');
        const data = await res.json();
        alert(data.stdout || data.stderr || 'Diagnóstico completado');
      } finally {
        btn.disabled = false;
        btn.innerHTML = '<span>🩺</span> Ejecutar Doctor';
      }
    }

    function openModal() {
      document.getElementById('modal-comment').value = '';
      document.getElementById('action-modal').classList.remove('hidden');
    }

    function closeModal() {
      document.getElementById('action-modal').classList.add('hidden');
    }

    // Inicializar y polling cada 3 segundos
    fetchData();
    setInterval(fetchData, 3000);
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

            if action == "approve" and task_id:
                cmd = ["approve", task_id]
                if payload.get("status"):
                    cmd.extend(["--status", payload["status"]])
                if payload.get("comment"):
                    cmd.extend(["--comment", payload["comment"]])
                res = run_command(cmd)
            elif action == "hold" and task_id:
                cmd = ["hold", task_id]
                if payload.get("reason"):
                    cmd.append(payload["reason"])
                res = run_command(cmd)
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
    import argparse
    parser = argparse.ArgumentParser(description="Live Dashboard Server para SKILL MAESTRO")
    parser.add_argument("--port", type=int, default=4200, help="Puerto HTTP (por defecto 4200)")
    parser.add_argument("--host", default="127.0.0.1", help="Host bind (por defecto 127.0.0.1)")
    args = parser.parse_args()

    server_address = (args.host, args.port)
    httpd = HTTPServer(server_address, DashboardHandler)
    print(f"🚀 SKILL MAESTRO Live Dashboard activo en: http://{args.host}:{args.port}")
    print("   Presiona Ctrl+C para detener el servidor.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nDeteniendo servidor...")
        httpd.server_close()

if __name__ == "__main__":
    main()
