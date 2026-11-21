#!/usr/bin/env python3
"""Checks deterministas de la eval finops-rightsizing-logs (sin dependencias).

Uso (desde la raíz del proyecto): python3 finops_check.py <functions|storage|sql|report>
Sale con 0 si cumple; si no, explica el motivo y sale con 1.
"""
import json
import re
import sys
from pathlib import Path

PRICE_GB_S = 0.0000166667
ORIGINAL_MB = 3008


def fail(msg):
    print(f"❌ {msg}")
    sys.exit(1)


def thumbnail():
    fns = json.loads(Path("infra/functions.json").read_text(encoding="utf-8"))["functions"]
    return next(f for f in fns if f["name"] == "thumbnail")


def functions():
    f = thumbnail()
    mem, tmo = f.get("memoryMb"), f.get("timeoutS")
    p95 = f["metrics30d"]["p95MemoryUsedMb"]
    if not isinstance(mem, (int, float)) or mem >= ORIGINAL_MB:
        fail(f"memoryMb sigue sobredimensionada ({mem})")
    if mem < p95 * 1.4:
        fail(f"memoryMb {mem} deja menos del 40 % de margen sobre el p95 medido ({p95} MB): riesgo de quedarse sin memoria")
    if mem > 1024:
        fail(f"memoryMb {mem}: con un p95 de {p95} MB sigue sobredimensionada")
    if not isinstance(tmo, (int, float)) or not 2 <= tmo <= 60:
        fail(f"timeoutS {tmo} no es acorde a una duración p95 de 0,7 s (esperado entre 2 y 60)")


def storage():
    b = next(x for x in json.loads(Path("infra/storage.json").read_text(encoding="utf-8"))["buckets"] if x["name"] == "app-logs")
    rules = b.get("lifecycleRules") or []
    if not rules:
        fail("app-logs sigue sin reglas de ciclo de vida")
    transitions = [t for r in rules for t in r.get("transitions", [])]
    cheaper = [t for t in transitions if t.get("storageClass") not in (None, "STANDARD")]
    if not cheaper:
        fail("ninguna regla mueve los logs a una clase más barata")
    if any(t.get("days", 0) < 30 for t in cheaper):
        fail("mover los logs antes de 30 días encarece las lecturas frecuentes")
    exp = [r["expirationDays"] for r in rules if "expirationDays" in r]
    if not exp:
        fail("los logs no se borran nunca: falta expirationDays tras la retención")
    if min(exp) < 365:
        fail(f"expirationDays {min(exp)} borra los logs antes de la retención obligatoria de 365 días")


def sql():
    q = Path("analytics/daily_revenue.sql").read_text(encoding="utf-8")
    code = re.sub(r"--[^\n]*", "", q)
    if re.search(r"select\s+(\w+\.)?\*", code, re.I):
        fail("la consulta sigue usando SELECT *")
    where = re.search(r"\bwhere\b(.*)", code, re.I | re.S)
    if not where or not re.search(r"\bevent_date\b", where.group(1), re.I):
        fail("la consulta no filtra por la columna de partición event_date")
    if not re.search(r"purchase", code, re.I):
        fail("la consulta ya no se limita a las compras")


def report():
    p = Path("docs/finops/report.md")
    if not p.is_file():
        fail("falta docs/finops/report.md")
    f = thumbnail()
    m = f["metrics30d"]
    expected = m["invocationsPerMonth"] * m["avgDurationMs"] / 1000 * (ORIGINAL_MB - f["memoryMb"]) / 1024 * PRICE_GB_S
    text = p.read_text(encoding="utf-8")
    nums = []
    for raw in re.findall(r"\d[\d.,]*", text):
        s = raw.rstrip(".,")
        if re.fullmatch(r"\d{1,3}(\.\d{3})+,\d+", s):      # 1.234,56
            s = s.replace(".", "").replace(",", ".")
        elif re.fullmatch(r"\d+,\d{1,2}", s):               # 32,50
            s = s.replace(",", ".")
        else:
            s = s.replace(",", "")
        try:
            nums.append(float(s))
        except ValueError:
            pass
    if not any(abs(n - expected) <= expected * 0.10 for n in nums):
        fail(f"el informe no recoge el ahorro mensual de la función (~{expected:.2f} USD con {f['memoryMb']} MB)")


if __name__ == "__main__":
    {"functions": functions, "storage": storage, "sql": sql, "report": report}[sys.argv[1]]()
