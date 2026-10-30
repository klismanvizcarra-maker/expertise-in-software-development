#!/usr/bin/env python3
"""
Ejecuta la batería de activación contra Claude Code real (modo --print) y mide qué skill carga el modelo.

Para cada caso:
  - Instala el sistema en un proyecto temporal (init-project.sh) con un GLOBAL_STATE.md de ejemplo.
  - Lanza `claude -p "<prompt>"` con solo herramientas de lectura (Skill, Read, Glob, Grep): nada se modifica.
  - Lee el stream JSON y registra las skills cargadas (herramienta Skill o lectura directa de un SKILL.md).
  - Corta la sesión en cuanto el modelo empieza a trabajar tras cargar skills, para gastar lo mínimo.

Uso:
  python3 tests/triggers/run_claude.py                      # todos los casos
  python3 tests/triggers/run_claude.py --only be-01,db-01   # casos concretos
  python3 tests/triggers/run_claude.py --model sonnet --jobs 4 --budget 0.25

Gasta uso de tu cuenta: cada caso es una sesión corta (límite por caso con --budget, en USD).
Resultados en tests/triggers/results/<fecha>.json y resumen por pantalla.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CASES = Path(__file__).with_name("cases.json")
RESULTS_DIR = Path(__file__).with_name("results")
SKILL_FILE_RX = re.compile(r"(?:\.agents|\.claude)/skills/([a-z0-9-]+)/SKILL\.md")


def find_claude() -> str:
    env = os.environ.get("CLAUDE_BIN")
    if env:
        return env
    found = shutil.which("claude")
    if found:
        return found
    base = Path.home() / "Library/Application Support/Claude/claude-code"
    candidates = sorted(base.glob("*/*/claude.app/Contents/MacOS/claude"))
    if candidates:
        return str(candidates[-1])
    sys.exit("No se encontró la CLI de Claude Code. Define CLAUDE_BIN con su ruta.")


def system_skills() -> set[str]:
    return {p.parent.name for p in (ROOT / ".agents/skills").glob("*/SKILL.md")}


def make_project() -> Path:
    tmp = Path(tempfile.mkdtemp(prefix="skill-triggers-"))
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=tmp, check=True)
    subprocess.run(["bash", str(ROOT / ".agents/scripts/init-project.sh"), "Proyecto Demo", str(tmp)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # Estado realista: stack declarado y algunas tareas en distintos estados
    state = tmp / "GLOBAL_STATE.md"
    s = state.read_text()
    s = s.replace("`[Framework: ej. React 19 / Angular 19 / Next.js / Vue 3]`", "`Angular 22`")
    s = s.replace("`[Runtime / Framework: ej. Node.js + Express / Fastify / Python FastAPI / Go]`", "`Node 24 + Express 5`")
    s = s.replace("`[Base de datos: ej. PostgreSQL / SQLite / MongoDB / Redis]`", "`PostgreSQL 18 + Drizzle`")
    state.write_text(s)
    # Commit inicial para que start pueda crear ramas por tarea y volver a main al final
    git = ["git", "-c", "user.name=triggers", "-c", "user.email=triggers@example.com"]
    subprocess.run(["git", "add", "-A"], cwd=tmp, check=True)
    subprocess.run(git + ["commit", "-qm", "chore(TASK-000): instalar sistema", "--no-verify"], cwd=tmp, check=True)
    # Tareas sembradas (TASK-003 en adelante) para los casos de tipo 'especialista'.
    # Los estados se alcanzan con las transiciones reales (move no lleva a IN_PROGRESS ni a IN_REVIEW_QA)
    task = ["bash", str(tmp / ".agents/scripts/task.sh")]
    steps = {"TODO": [], "IN_PROGRESS": ["start"], "IN_REVIEW_QA": ["start", "handoff"]}
    seeds = json.loads(CASES.read_text()).get("_seed_tasks", [])
    for i, seed in enumerate(seeds, start=3):
        tid = f"TASK-{i:03d}"
        status = seed.get("status", "TODO")
        if status not in steps:
            sys.exit(f"_seed_tasks: estado no sembrable '{status}' en {tid} (válidos: {', '.join(steps)})")
        subprocess.run(task + ["add", seed["desc"], seed["agent"], "Criterios definidos en el PRD"],
                       cwd=tmp, check=True, stdout=subprocess.DEVNULL)
        for step in steps[status]:
            subprocess.run(task + [step, tid], cwd=tmp, check=True, stdout=subprocess.DEVNULL)
    subprocess.run(["git", "checkout", "-q", "main"], cwd=tmp, check=True)
    return tmp


def clean_env() -> dict:
    # Si este script corre dentro de otra sesión de Claude (app de escritorio, IDE), las variables
    # CLAUDE_*/ANTHROPIC_* heredadas hacen que la CLI ignore la sesión iniciada con `auth login`.
    return {k: v for k, v in os.environ.items() if not k.startswith(("CLAUDE", "ANTHROPIC"))}


def run_case(claude: str, project: Path, case: dict, args, known: set[str]) -> dict:
    cmd = [
        claude, "-p", case["prompt"],
        "--output-format", "stream-json", "--verbose",
        "--tools", "Skill,Read,Glob,Grep",
        "--strict-mcp-config",
        "--no-session-persistence",
        "--max-budget-usd", str(args.budget),
    ]
    if args.model:
        cmd += ["--model", args.model]

    loaded: list[str] = []
    working_after_load = 0
    error = None
    cost = 0.0
    started = time.time()
    proc = subprocess.Popen(cmd, cwd=project, env=clean_env(), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, text=True)
    timer = threading.Timer(args.timeout, proc.kill)
    timer.start()
    try:
        for line in proc.stdout:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("type") == "result":
                cost = event.get("total_cost_usd") or 0.0
                text = str(event.get("result", ""))
                if event.get("is_error") or "Not logged in" in text or "/login" in text:
                    error = text[:200] or "error"
                continue
            if event.get("type") != "assistant":
                continue
            for block in event.get("message", {}).get("content", []):
                if block.get("type") == "tool_use":
                    name, inp = block.get("name"), block.get("input", {})
                    skill = None
                    if name == "Skill":
                        skill = str(inp.get("skill") or inp.get("command") or "").lstrip("/").split(":")[-1]
                    elif name == "Read":
                        m = SKILL_FILE_RX.search(str(inp.get("file_path", "")))
                        skill = m.group(1) if m else None
                    if skill:
                        if skill not in loaded:
                            loaded.append(skill)
                        continue
                    if loaded:
                        working_after_load += 1
                elif block.get("type") == "text" and loaded and block.get("text", "").strip():
                    working_after_load += 1
            # Tras cargar skills, dejamos un par de pasos por si carga otra (rol + stack) y cortamos
            if working_after_load >= 2:
                proc.kill()
                break
    finally:
        timer.cancel()
        proc.kill()
        proc.wait()

    if error and not loaded:
        return {"id": case["id"], "prompt": case["prompt"], "expect": case["expect"], "loaded": [], "ours": [],
                "pass": False, "error": error, "forbidden": [], "extra": [], "cost": cost,
                "seconds": round(time.time() - started, 1)}
    ours = [s for s in loaded if s in known]
    expect, accept, forbid = set(case["expect"]), set(case.get("accept", [])), set(case.get("forbid", []))
    # Acierto ideal: carga una de `expect`. Aceptable: solo carga alternativas válidas de `accept`.
    if expect:
        ideal = bool(expect & set(ours))
        hit = ideal or bool(accept & set(ours))
    else:
        ideal = hit = not (set(ours) - accept)
    forbidden = sorted(set(ours) & forbid)
    extra = sorted(set(ours) - expect - accept - forbid)
    return {
        "id": case["id"], "prompt": case["prompt"], "expect": case["expect"],
        "loaded": loaded, "ours": ours, "pass": hit and not forbidden, "ideal": ideal and not forbidden,
        "forbidden": forbidden, "extra": extra, "cost": cost, "error": None, "seconds": round(time.time() - started, 1),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--model", default="")
    ap.add_argument("--jobs", type=int, default=3)
    ap.add_argument("--budget", type=float, default=0.25)
    ap.add_argument("--timeout", type=int, default=120)
    args = ap.parse_args()

    cases = json.loads(CASES.read_text())["cases"]
    if args.only:
        wanted = set(args.only.split(","))
        cases = [c for c in cases if c["id"] in wanted]
    claude = find_claude()
    known = system_skills()
    project = make_project()
    print(f"CLI: {claude}\nProyecto temporal: {project}\nCasos: {len(cases)} · paralelo: {args.jobs}\n")

    probe = run_case(claude, project, {"id": "probe", "prompt": "Responde solo: ok", "expect": []}, args, known)
    if probe["error"]:
        shutil.rmtree(project, ignore_errors=True)
        sys.exit(f"❌ La CLI no puede ejecutar sesiones: {probe['error']}\n"
                 "   Inicia sesión una vez en una terminal con:  \"<ruta de claude>\" auth login  (o define ANTHROPIC_API_KEY).")

    results = []
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run_case, claude, project, c, args, known) for c in cases]
        for f in futures:
            r = f.result()
            results.append(r)
            mark = "⚠️ " if r.get("error") else ("✅" if r.get("ideal") else ("🟡" if r["pass"] else "❌"))
            got = ", ".join(r["ours"]) or "(ninguna)"
            exp = " | ".join(r["expect"]) or "(ninguna)"
            note = f"  ⛔ prohibidas: {', '.join(r['forbidden'])}" if r["forbidden"] else ""
            print(f"{mark} {r['id']:<8} esperado: {exp:<45} cargó: {got}{note}")

    passed = sum(r["pass"] for r in results)
    ideal = sum(bool(r.get("ideal")) for r in results)
    cost = sum(r.get("cost") or 0 for r in results)
    print(f"\nAcierto: {passed}/{len(results)} ({100 * passed // max(len(results), 1)}%) · ideal ✅ {ideal} · "
          f"aceptable 🟡 {passed - ideal} · coste aprox.: {cost:.2f} USD")

    RESULTS_DIR.mkdir(exist_ok=True)
    out = RESULTS_DIR / f"{datetime.now():%Y-%m-%d_%H%M}-claude.json"
    out.write_text(json.dumps({"model": args.model or "default", "results": results}, ensure_ascii=False, indent=2))
    print(f"Detalle: {out.relative_to(ROOT)}")
    shutil.rmtree(project, ignore_errors=True)
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
