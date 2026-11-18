#!/usr/bin/env python3
"""
Evals de calidad de salida: ¿la skill produce el resultado correcto, no solo se activa?

Para cada eval de evals.json:
  - Instala el sistema en un proyecto temporal con git (init-project.sh) y ejecuta 'setup'.
  - Lanza `claude -p "<prompt>"` con herramientas de escritura (Edit, Write, Bash) dentro de ese proyecto.
  - Ejecuta los 'checks' (bash, exit 0 = cumple) sobre el estado final: tablero, tests, git, BRAIN.md.

Uso:
  python3 tests/evals/run_evals.py                         # todas
  python3 tests/evals/run_evals.py --only qa-reject-idor   # algunas
  python3 tests/evals/run_evals.py --keep                  # conserva los proyectos para inspeccionarlos
  python3 tests/evals/run_evals.py --verify-baselines      # sin LLM: cada eval debe fallar tras el setup (FAIL_INIT)

--verify-baselines no lanza Claude ni gasta nada: instala, ejecuta el setup y los checks, y falla si
alguna eval pasa en el estado inicial (no mediría nada) o si su setup falla. Lo ejecutan
tests/test-scripts.sh y la CI.

Las demás formas gastan uso de tu cuenta (límite por eval con --budget, en USD). Los proyectos temporales no tocan este repositorio.
Resultados en tests/evals/results/<fecha>.json.
"""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
sys.path.insert(0, str(ROOT / "tests/triggers"))
from run_claude import clean_env, find_claude  # noqa: E402

RESULTS_DIR = HERE / "results"

# Disponible en setup y checks
PRELUDE = r"""
T=./.agents/scripts/task.sh
col() {
  awk -F'|' -v id="$1" -v c="$2" '/^\|/ { x=$2; gsub(/[ \t`]/,"",x); if (x==id) { v=$c; gsub(/^[ \t`]+|[ \t`]+$/,"",v); print v; exit } }' GLOBAL_STATE.md
}
"""


def sh(script: str, cwd: Path, timeout: int = 120) -> subprocess.CompletedProcess:
    env = clean_env() | {"FIXTURES": str(HERE / "fixtures")}
    return subprocess.run(["bash", "-c", PRELUDE + script], cwd=cwd, env=env, text=True,
                          capture_output=True, timeout=timeout)


def make_project(eval_id: str) -> Path:
    tmp = Path(tempfile.mkdtemp(prefix=f"skill-eval-{eval_id}-"))
    for cmd in (["git", "init", "-q", "-b", "main"],
                ["git", "config", "user.email", "eval@example.com"],
                ["git", "config", "user.name", "eval"]):
        subprocess.run(cmd, cwd=tmp, check=True)
    subprocess.run(["bash", str(ROOT / ".agents/scripts/init-project.sh"), "Proyecto Eval", str(tmp)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["git", "add", "-A"], cwd=tmp, check=True)
    subprocess.run(["git", "commit", "-qm", "chore(TASK-000): instalar sistema", "--no-verify"], cwd=tmp, check=True)
    return tmp


def run_eval(claude: str, ev: dict, args) -> dict:
    started = time.time()
    project = make_project(ev["id"])
    out = {"id": ev["id"], "skill": ev["skill"], "project": str(project), "checks": [], "error": None, "cost": 0.0}
    setup = sh(ev["setup"], project)
    if setup.returncode != 0:
        out["error"] = f"setup falló: {setup.stderr.strip()[:300]}"
        return out
    subprocess.run(["git", "tag", "eval-start"], cwd=project, check=True)

    cmd = [claude, "-p", ev["prompt"], "--output-format", "json",
           "--tools", "Skill,Read,Glob,Grep,Edit,Write,Bash",
           "--permission-mode", "acceptEdits", "--allowedTools", "Bash",
           "--strict-mcp-config", "--no-session-persistence",
           "--max-budget-usd", str(args.budget)]
    if args.model:
        cmd += ["--model", args.model]
    try:
        proc = subprocess.run(cmd, cwd=project, env=clean_env(), stdin=subprocess.DEVNULL,
                              capture_output=True, text=True, timeout=args.timeout)
        try:
            res = json.loads(proc.stdout)
            out["cost"] = res.get("total_cost_usd") or 0.0
            out["final"] = str(res.get("result", ""))[:1500]
            if res.get("is_error") and not res.get("result"):
                out["error"] = res.get("subtype") or "error"
        except json.JSONDecodeError:
            out["error"] = (proc.stderr or proc.stdout).strip()[:300] or "salida no JSON"
    except subprocess.TimeoutExpired:
        out["error"] = f"timeout ({args.timeout}s)"

    for name, script in ev["checks"]:
        r = sh(script, project)
        out["checks"].append({"name": name, "pass": r.returncode == 0,
                              "detail": (r.stdout + r.stderr).strip()[:200]})
    out["pass"] = bool(out["checks"]) and all(c["pass"] for c in out["checks"])
    out["seconds"] = round(time.time() - started, 1)
    if not args.keep:
        shutil.rmtree(project, ignore_errors=True)
    return out


def verify_baseline(ev: dict) -> dict:
    """FAIL_INIT: tras el setup, sin que la skill haga nada, al menos un check debe fallar."""
    project = make_project(ev["id"])
    out = {"id": ev["id"], "skill": ev["skill"], "error": None, "checks": []}
    try:
        setup = sh(ev["setup"], project)
        if setup.returncode != 0:
            out["error"] = f"setup falló: {(setup.stderr or setup.stdout).strip()[-300:]}"
            return out
        subprocess.run(["git", "tag", "eval-start"], cwd=project, check=True)
        for name, script in ev["checks"]:
            r = sh(script, project, timeout=300)
            out["checks"].append({"name": name, "pass": r.returncode == 0})
    except subprocess.TimeoutExpired as exc:
        out["error"] = f"timeout: {exc}"
    finally:
        shutil.rmtree(project, ignore_errors=True)
    out["fail_init"] = bool(out["checks"]) and not all(c["pass"] for c in out["checks"])
    return out


def verify_baselines(evals: list, jobs: int) -> int:
    print(f"Verificando la línea base (FAIL_INIT) de {len(evals)} evals, sin LLM · paralelo: {jobs}\n")
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        results = list(pool.map(verify_baseline, evals))
    bad = 0
    for r in results:
        if r["error"]:
            bad += 1
            print(f"❌ {r['id']:<32} {r['error']}")
            continue
        failing = [c["name"] for c in r["checks"] if not c["pass"]]
        if r["fail_init"]:
            print(f"✅ {r['id']:<32} {len(failing)}/{len(r['checks'])} checks fallan en el estado inicial")
        else:
            bad += 1
            print(f"❌ {r['id']:<32} todos los checks pasan sin que la skill haga nada: la eval no mide nada")
    print(f"\nLínea base: {len(results) - bad}/{len(results)} evals correctas")
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--model", default="")
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--budget", type=float, default=1.5)
    ap.add_argument("--timeout", type=int, default=600)
    ap.add_argument("--keep", action="store_true")
    ap.add_argument("--file", default=str(HERE / "evals.json"), help="evals.json alternativo (pruebas)")
    ap.add_argument("--verify-baselines", action="store_true",
                    help="sin LLM: comprueba que cada eval falla tras el setup (FAIL_INIT)")
    args = ap.parse_args()

    evals = json.loads(Path(args.file).read_text(encoding="utf-8"))["evals"]
    if args.only:
        wanted = set(args.only.split(","))
        evals = [e for e in evals if e["id"] in wanted]
        missing = wanted - {e["id"] for e in evals}
        if missing:
            print(f"Evals inexistentes: {', '.join(sorted(missing))}", file=sys.stderr)
            return 2
    if args.verify_baselines:
        return verify_baselines(evals, max(args.jobs, 1))
    claude = find_claude()
    print(f"CLI: {claude}\nEvals: {len(evals)} · paralelo: {args.jobs} · límite por eval: {args.budget} USD\n")

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(lambda e: run_eval(claude, e, args), evals))

    for r in results:
        mark = "⚠️ " if r.get("error") and not r.get("checks") else ("✅" if r.get("pass") else "❌")
        print(f"{mark} {r['id']:<28} ({r['skill']}) · {r.get('cost', 0):.2f} USD")
        if r.get("error"):
            print(f"     error: {r['error']}")
        for c in r["checks"]:
            print(f"     {'✓' if c['pass'] else '✗'} {c['name']}" + (f"  [{c['detail']}]" if not c["pass"] and c["detail"] else ""))
        if args.keep:
            print(f"     proyecto: {r['project']}")

    passed = sum(bool(r.get("pass")) for r in results)
    checks = [c for r in results for c in r["checks"]]
    cost = sum(r.get("cost") or 0 for r in results)
    print(f"\nEvals: {passed}/{len(results)} · checks: {sum(c['pass'] for c in checks)}/{len(checks)} · coste aprox.: {cost:.2f} USD")

    RESULTS_DIR.mkdir(exist_ok=True)
    out = RESULTS_DIR / f"{datetime.now():%Y-%m-%d_%H%M}.json"
    out.write_text(json.dumps({"model": args.model or "default", "results": results}, ensure_ascii=False, indent=2))
    print(f"Detalle: {out.relative_to(ROOT)}")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
