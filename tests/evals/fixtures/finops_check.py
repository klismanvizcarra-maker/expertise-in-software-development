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
    cheaper = [t for t in transitions if str(t.get("storageClass", "")).upper() in ("STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING", "GLACIER_IR", "GLACIER", "DEEP_ARCHIVE")]
    if not cheaper:
        fail("ninguna regla mueve los logs a una clase más barata")
    if any(t.get("days", 0) < 30 for t in cheaper):
        fail("mover los logs antes de 30 días encarece las lecturas frecuentes")
    exp = [r["expirationDays"] for r in rules if "expirationDays" in r]
    if not exp:
        fail("los logs no se borran nunca: falta expirationDays tras la retención")
    if min(exp) < 365:
        fail(f"expirationDays {min(exp)} borra los logs antes de la retención obligatoria de 365 días")


def depths(code):
    """Profundidad de paréntesis de cada carácter."""
    out, d = [], 0
    for ch in code:
        if ch == ")":
            d = max(d - 1, 0)
        out.append(d)
        if ch == "(":
            d += 1
    return out


def drop_subqueries(text):
    """Sustituye cada '(SELECT ...)' (con paréntesis anidados) por '()'."""
    while True:
        m = re.search(r"\(\s*select\b", text, re.I)
        if not m:
            return text
        d, i = 0, m.start()
        for j in range(m.start(), len(text)):
            d += {"(": 1, ")": -1}.get(text[j], 0)
            if d == 0:
                break
        text = text[:i] + "()" + text[j + 1:]


def sql():
    q = Path("analytics/daily_revenue.sql").read_text(encoding="utf-8")
    code = re.sub(r"/\*.*?\*/", " ", q, flags=re.S)
    code = re.sub(r"--[^\n]*", " ", code)
    has_purchase = re.search(r"'purchase'", code, re.I)
    code = re.sub(r"'(?:[^']|'')*'", "'x'", code)
    if re.search(r"\bselect\s+(distinct\s+|all\s+)?([\w`\"]+\.)?\*", code, re.I):
        fail("la consulta sigue usando SELECT *")
    dep = depths(code)
    # WHERE de la consulta principal: el primero a profundidad 0 (los de CTE y subconsultas van entre paréntesis)
    w = next((m for m in re.finditer(r"\bwhere\b", code, re.I) if dep[m.start()] == 0), None)
    if not w:
        fail("la consulta principal no tiene WHERE")
    end = len(code)
    for m in re.finditer(r"\bgroup\s+by\b|\bhaving\b|\border\s+by\b|\blimit\b|\bqualify\b|\bwindow\b|\bunion\b|;", code[w.end():], re.I):
        if dep[w.end() + m.start()] == 0:
            end = w.end() + m.start()
            break
    clause = drop_subqueries(code[w.end():end])
    cmp = r"(=|<>|!=|<=|>=|<|>|\bbetween\b|\bin\b)"
    if not re.search(r"\bevent_date\b\s*" + cmp + r"|" + r"(=|<=|>=|<|>)\s*([\w`\"]+\.)?event_date\b", clause, re.I):
        fail("la consulta principal no filtra en su WHERE por la columna de partición event_date")
    if not has_purchase:
        fail("la consulta ya no se limita a las compras (event_type = 'purchase')")


def report():
    p = Path("docs/finops/report.md")
    if not p.is_file():
        fail("falta docs/finops/report.md")
    f = thumbnail()
    m = f["metrics30d"]
    expected = m["invocationsPerMonth"] * m["avgDurationMs"] / 1000 * (ORIGINAL_MB - f["memoryMb"]) / 1024 * PRICE_GB_S
    # Solo cuentan importes en USD (no un "día 35" casual); el ahorro puede ir en una fila de tabla
    text = p.read_text(encoding="utf-8")
    nums = []
    # Importes en USD: "32,50 USD", "USD 32.50", "$32.50" o "32.50 $" / "dólares"
    money = r"(?:US\$|\$|USD)\s*(\d[\d.,]*)|(\d[\d.,]*)\s*(?:USD|US\$|\$|d[oó]lares)"
    for raw in [a or b for a, b in re.findall(money, text, re.I)]:
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
