#!/usr/bin/env python3
"""
Generador de Dashboard HTML interactivo y autónomo para SKILL MAESTRO.
Uso: python3 generate-dashboard.py <GLOBAL_STATE.md> <BRAIN.md> <lessons_learned.md> <tech_debt.md> <output.html>
"""
import sys
import os
import re
import html
import glob

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

def main():
    if len(sys.argv) < 6:
        print("Uso: generate-dashboard.py <state_file> <brain_file> <lessons_file> <debt_file> <output_file>")
        sys.exit(1)

    state_path = sys.argv[1]
    brain_path = sys.argv[2]
    lessons_path = sys.argv[3]
    debt_path = sys.argv[4]
    output_path = sys.argv[5]

    # Leer archivos
    with open(state_path, 'r', encoding='utf-8') as f:
        state_content = f.read()

    lessons_content = ""
    if os.path.exists(lessons_path):
        with open(lessons_path, 'r', encoding='utf-8') as f:
            lessons_content = f.read()

    debt_content = ""
    if os.path.exists(debt_path):
        with open(debt_path, 'r', encoding='utf-8') as f:
            debt_content = f.read()

    # Metadatos del proyecto
    proj_name = re.search(r'-\s*\*\*Proyecto\*\*:\s*`([^`]+)`', state_content)
    proj_name = proj_name.group(1) if proj_name else "SKILL MAESTRO"
    
    phase = re.search(r'-\s*\*\*Fase Actual\*\*:\s*`([^`]+)`', state_content)
    phase = phase.group(1) if phase else "En curso"

    update_date = re.search(r'-\s*\*\*Última Actualización\*\*:\s*`([^`]+)`', state_content)
    update_date = update_date.group(1) if update_date else "Hoy"

    # Tareas activas
    _, board_rows = parse_markdown_table(state_content, r'##\s*5\.\s*Tablero de Tareas')
    
    # Tareas archivadas
    archived_rows = []
    archive_dir = os.path.join(os.path.dirname(state_path), '.agents', 'archive')
    if os.path.isdir(archive_dir):
        for arch_file in sorted(glob.glob(os.path.join(archive_dir, '*.md'))):
            with open(arch_file, 'r', encoding='utf-8') as af:
                _, a_rows = parse_markdown_table(af.read(), r'\|\s*ID Tarea\s*\|')
                archived_rows.extend(a_rows)

    all_tasks = []
    for r in board_rows:
        if len(r) >= 6:
            all_tasks.append({
                'id': re.sub(r'[`\s]', '', r[0]),
                'desc': r[1],
                'agent': r[2],
                'status': re.sub(r'[`\s]', '', r[3]),
                'iter': r[4],
                'criteria': r[5],
                'archived': False
            })
    for r in archived_rows:
        if len(r) >= 6:
            all_tasks.append({
                'id': re.sub(r'[`\s]', '', r[0]),
                'desc': r[1],
                'agent': r[2],
                'status': re.sub(r'[`\s]', '', r[3]),
                'iter': r[4],
                'criteria': r[5],
                'archived': True
            })

    total_tasks = len(all_tasks)
    done_tasks = len([t for t in all_tasks if t['status'] == 'DONE'])
    progress_pct = int((done_tasks / total_tasks * 100)) if total_tasks > 0 else 0

    # Lecciones y deuda
    _, lesson_rows = parse_markdown_table(lessons_content, r'\|\s*ID\s*\|\s*Fecha\s*\|')
    active_lessons = [r for r in lesson_rows if len(r) >= 8 and 'OBSOLETA' not in r[7].upper()]
    
    _, debt_rows = parse_markdown_table(debt_content, r'\|\s*ID\s*\|\s*Tarea Vinculada\s*\|')
    pending_debt = [r for r in debt_rows if len(r) >= 8 and 'SALDADA' not in r[7].upper()]

    # HTML Generator
    status_columns = ['TODO', 'AWAITING_HUMAN_APPROVAL', 'IN_PROGRESS', 'IN_REVIEW_QA', 'BLOCKED', 'DONE']
    columns_data = {s: [] for s in status_columns}
    for t in all_tasks:
        st = t['status']
        if st in columns_data:
            columns_data[st].append(t)
        else:
            columns_data['TODO'].append(t)

    html_out = f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Dashboard — {html.escape(proj_name)}</title>
  <style>
    :root {{
      --bg: #0f172a;
      --card-bg: #1e293b;
      --text: #f8fafc;
      --text-muted: #94a3b8;
      --primary: #3b82f6;
      --success: #10b981;
      --warning: #f59e0b;
      --danger: #ef4444;
      --border: #334155;
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }}
    body {{ background: var(--bg); color: var(--text); padding: 24px; line-height: 1.5; }}
    header {{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; border-bottom: 1px solid var(--border); padding-bottom: 16px; }}
    h1 {{ font-size: 1.6rem; color: var(--text); font-weight: 700; }}
    .badge-phase {{ background: rgba(59, 130, 246, 0.2); color: #60a5fa; padding: 4px 12px; border-radius: 9999px; font-size: 0.85rem; font-weight: 600; }}
    .kpis {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; margin-bottom: 24px; }}
    .kpi-card {{ background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; padding: 16px; }}
    .kpi-title {{ font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase; font-weight: 600; }}
    .kpi-value {{ font-size: 1.8rem; font-weight: 700; margin-top: 4px; }}
    .progress-bar {{ width: 100%; height: 8px; background: #334155; border-radius: 4px; margin-top: 8px; overflow: hidden; }}
    .progress-fill {{ height: 100%; background: var(--success); width: {progress_pct}%; transition: width 0.3s; }}
    .kanban {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; margin-bottom: 32px; }}
    .column {{ background: rgba(30, 41, 59, 0.5); border: 1px solid var(--border); border-radius: 8px; display: flex; flex-direction: column; max-height: 80vh; }}
    .column-header {{ padding: 12px 16px; border-bottom: 1px solid var(--border); font-weight: 700; display: flex; justify-content: space-between; align-items: center; }}
    .column-body {{ padding: 12px; overflow-y: auto; flex-grow: 1; display: flex; flex-direction: column; gap: 10px; }}
    .task-card {{ background: var(--card-bg); border: 1px solid var(--border); border-radius: 6px; padding: 12px; font-size: 0.9rem; box-shadow: 0 1px 3px rgba(0,0,0,0.2); }}
    .task-header {{ display: flex; justify-content: space-between; margin-bottom: 6px; font-size: 0.8rem; }}
    .task-id {{ font-weight: 700; color: #93c5fd; }}
    .task-iter {{ background: rgba(245, 158, 11, 0.2); color: #fbbf24; padding: 2px 6px; border-radius: 4px; font-size: 0.75rem; }}
    .task-desc {{ margin-bottom: 8px; font-weight: 500; }}
    .task-agent {{ font-size: 0.75rem; color: var(--text-muted); display: inline-block; background: rgba(255,255,255,0.05); padding: 2px 6px; border-radius: 4px; }}
    .task-archived {{ opacity: 0.7; border-style: dashed; }}
    .section-title {{ font-size: 1.2rem; font-weight: 700; margin-bottom: 16px; border-bottom: 1px solid var(--border); padding-bottom: 8px; }}
    .brain-section {{ background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; padding: 20px; }}
    table {{ width: 100%; border-collapse: collapse; margin-top: 12px; font-size: 0.85rem; }}
    th, td {{ text-align: left; padding: 8px 12px; border-bottom: 1px solid var(--border); }}
    th {{ color: var(--text-muted); font-weight: 600; }}
  </style>
</head>
<body>
  <header>
    <div>
      <h1>🚀 {html.escape(proj_name)} — Dashboard</h1>
      <p style="color: var(--text-muted); font-size: 0.85rem;">Última actualización: {html.escape(update_date)}</p>
    </div>
    <div>
      <span class="badge-phase">{html.escape(phase)}</span>
    </div>
  </header>

  <div class="kpis">
    <div class="kpi-card">
      <div class="kpi-title">Progreso Total</div>
      <div class="kpi-value" style="color: var(--success);">{progress_pct}%</div>
      <div class="progress-bar"><div class="progress-fill"></div></div>
    </div>
    <div class="kpi-card">
      <div class="kpi-title">Tareas Totales</div>
      <div class="kpi-value">{total_tasks}</div>
      <p style="color: var(--text-muted); font-size: 0.8rem; margin-top: 4px;">{done_tasks} completadas</p>
    </div>
    <div class="kpi-card">
      <div class="kpi-title">Lecciones Activas</div>
      <div class="kpi-value" style="color: #60a5fa;">{len(active_lessons)}</div>
      <p style="color: var(--text-muted); font-size: 0.8rem; margin-top: 4px;">En cerebro persistente</p>
    </div>
    <div class="kpi-card">
      <div class="kpi-title">Deuda Técnica</div>
      <div class="kpi-value" style="color: { 'var(--danger)' if len(pending_debt) > 0 else 'var(--success)' };">{len(pending_debt)}</div>
      <p style="color: var(--text-muted); font-size: 0.8rem; margin-top: 4px;">Pendiente de resolver</p>
    </div>
  </div>

  <h2 class="section-title">Tablero de Tareas (Kanban)</h2>
  <div class="kanban">
"""
    for col in status_columns:
        tasks_in_col = columns_data[col]
        color_class = "var(--text)"
        if col == "BLOCKED": color_class = "var(--danger)"
        elif col == "DONE": color_class = "var(--success)"
        elif col == "IN_PROGRESS": color_class = "#60a5fa"
        elif col == "IN_REVIEW_QA": color_class = "var(--warning)"
        elif col == "AWAITING_HUMAN_APPROVAL": color_class = "#fbbf24"

        html_out += f"""    <div class="column">
      <div class="column-header">
        <span style="color: {color_class};">{col}</span>
        <span style="font-size: 0.8rem; color: var(--text-muted);">{len(tasks_in_col)}</span>
      </div>
      <div class="column-body">
"""
        for t in tasks_in_col:
            arch_cls = " task-archived" if t['archived'] else ""
            arch_badge = " (Archivada)" if t['archived'] else ""
            html_out += f"""        <div class="task-card{arch_cls}">
          <div class="task-header">
            <span class="task-id">{html.escape(t['id'])}{arch_badge}</span>
            <span class="task-iter">QA {html.escape(t['iter'])}</span>
          </div>
          <div class="task-desc">{html.escape(t['desc'])}</div>
          <span class="task-agent">👤 {html.escape(t['agent'])}</span>
        </div>
"""
        html_out += """      </div>
    </div>
"""

    html_out += f"""  </div>

  <div class="brain-section">
    <h2 class="section-title" style="margin-bottom: 8px;">🧠 Memoria Persistente y Salud del Cerebro</h2>
    <p style="color: var(--text-muted); font-size: 0.85rem;">{len(active_lessons)} lecciones activas con ámbito de rutas delimitado y {len(pending_debt)} items de deuda técnica pendiente.</p>
    
    <table>
      <thead>
        <tr>
          <th>ID</th>
          <th>Categoría</th>
          <th>Problema / Gotcha</th>
          <th>Solución / Antídoto</th>
        </tr>
      </thead>
      <tbody>
"""
    for l in active_lessons[:10]:
        lid = l[0] if len(l) > 0 else ""
        lcat = l[2] if len(l) > 2 else ""
        lprob = l[3] if len(l) > 3 else ""
        lsol = l[5] if len(l) > 5 else ""
        html_out += f"""        <tr>
          <td style="font-weight: 700; color: #93c5fd;">{html.escape(lid)}</td>
          <td><span class="badge-phase" style="font-size: 0.75rem;">{html.escape(lcat)}</span></td>
          <td>{html.escape(lprob)}</td>
          <td>{html.escape(lsol)}</td>
        </tr>
"""

    html_out += """      </tbody>
    </table>
  </div>
</body>
</html>
"""

    with open(output_path, 'w', encoding='utf-8') as out_f:
        out_f.write(html_out)

    print(f"OK:{output_path}")

if __name__ == '__main__':
    main()
