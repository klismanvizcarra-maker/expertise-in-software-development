#!/usr/bin/env python3
"""
Análisis estático de las descripciones de las skills (sin llamar a ningún modelo).

- Valida que cases.json solo use skills existentes y que toda skill tenga al menos dos casos.
- Comprueba que cada descripción diga cuándo usarla.
- Calcula la similitud entre descripciones (Jaccard de palabras de contenido) y marca
  los pares parecidos que no se delimitan entre sí con un "No usar ... (otra-skill)".
- Controla el presupuesto del listado de skills de Claude Code: ninguna descripción supera
  MAX_DESC_CHARS y la suma de todas no supera MAX_TOTAL_CHARS. Si el listado se pasa de su
  presupuesto (un porcentaje de la ventana de contexto), Claude Code deja skills sin descripción
  y el modelo ya no puede activarlas solas (LL-020).

Uso: python3 tests/triggers/lint_descriptions.py [--threshold 0.18] [--skills-dir DIR] [--cases FILE]
"""
from collections import Counter
import itertools
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def arg(name: str, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


SKILLS_DIR = Path(arg("--skills-dir", ROOT / ".agents" / "skills"))
CASES = Path(arg("--cases", Path(__file__).with_name("cases.json")))
THRESHOLD = float(arg("--threshold", 0.18))

# Presupuesto del listado de skills (caracteres de la descripción del frontmatter).
# 300 por skill deja sitio para qué hace, cuándo usarla y su límite con la skill vecina;
# 15000 en total cabe en el listado junto a las skills integradas y de plugins del usuario.
MAX_DESC_CHARS = 300
MAX_TOTAL_CHARS = 15000

STOPWORDS = set("""
a al algo ante antes como con contra cual cuando de del desde donde durante el ella ellas ellos en entre es esa ese eso esta este esto
estos estas la las le les lo los mas mientras muy no nos o otra otro para pero por que se segun si sin sobre su sus tambien tanto
te tras un una uno unos unas y ya usar usarlo usarla use when the and or for with of to in on a an is are be not no
cada todo toda todos todas hay ser sus solo sólo etc
""".split())


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in text if not unicodedata.combining(c))


def words(text: str) -> set[str]:
    return {w for w in re.findall(r"[a-z0-9]+", normalize(text)) if len(w) > 2 and w not in STOPWORDS}


def frontmatter(text: str) -> dict[str, str]:
    """Claves de primer nivel del frontmatter YAML: cualquier orden, valores entre comillas
    y bloques multilínea (> o |), sin depender de PyYAML."""
    text = text.replace("\r\n", "\n")
    m = re.match(r"^---[ \t]*\n(.*?)\n---[ \t]*(\n|$)", text, re.S)
    if not m:
        return {}
    data, key, block = {}, None, None
    for line in m.group(1).split("\n"):
        top = re.match(r"^([A-Za-z_][\w-]*):[ \t]*(.*)$", line)
        if top:
            key, value = top.group(1), top.group(2).strip()
            block = value[:1] if value[:1] in (">", "|") else None
            if block:
                value = ""
            elif len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            data[key] = value
        elif key and (block or line.startswith((" ", "\t"))):
            sep = "\n" if block == "|" else " "
            data[key] = (data[key] + sep + line.strip()).strip() if line.strip() else data[key]
    return data


def load_skills() -> tuple[dict[str, str], list[str]]:
    """Devuelve las skills legibles y las SKILL.md que no se pudieron leer: estas cuentan como
    problema, porque Claude Code sí las lista y gastan presupuesto sin que nadie las mida."""
    skills, unreadable = {}, []
    for f in sorted(SKILLS_DIR.glob("*/SKILL.md")):
        try:
            raw = f.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            unreadable.append(f"{f.parent.name}/SKILL.md (UTF-8 inválido)")
            continue
        fm = frontmatter(raw)
        if fm.get("name") and fm.get("description"):
            desc = fm["description"]
            if fm.get("when_to_use"):
                desc = (desc + " " + fm["when_to_use"]).strip()
            skills[fm["name"]] = desc
        else:
            unreadable.append(f"{f.parent.name}/SKILL.md")
    return skills, unreadable


def main() -> int:
    skills, unreadable = load_skills()
    cases = json.loads(CASES.read_text(encoding="utf-8"))["cases"]
    problems = 0

    print(f"Skills: {len(skills)} · Casos: {len(cases)}\n")
    for path in unreadable:
        print(f"❌ {path}: frontmatter sin name o description legibles (no se puede medir su presupuesto)")
        problems += 1

    # 1. Referencias de cases.json
    referenced = set()
    for c in cases:
        for key in ("expect", "accept", "forbid"):
            for name in c.get(key, []):
                referenced.add(name)
                if name not in skills:
                    print(f"❌ {c['id']}: '{name}' en {key} no es una skill existente")
                    problems += 1
    expect_counts = Counter(n for c in cases for n in c["expect"])
    for name in skills:
        if expect_counts[name] < 2:
            print(f"❌ '{name}' solo tiene {expect_counts[name]} caso(s) como esperada (mínimo 2)")
            problems += 1

    # 2. Cláusula de uso
    for name, desc in skills.items():
        if not re.search(r"\bUsar (cuando|siempre|al|para|tras|si)\b", desc):
            print(f"⚠️  '{name}': la descripción no dice cuándo usarla ('Usar cuando…')")
            problems += 1

    # 3. Presupuesto del listado de Claude Code
    total = 0
    for name, desc in skills.items():
        total += len(desc)
        if len(desc) > MAX_DESC_CHARS:
            print(f"❌ '{name}': descripción de {len(desc)} caracteres (máximo {MAX_DESC_CHARS})")
            problems += 1
    print(f"Presupuesto de descripciones: {total}/{MAX_TOTAL_CHARS} caracteres en total")
    if total > MAX_TOTAL_CHARS:
        print(f"❌ Las descripciones suman {total} caracteres (máximo {MAX_TOTAL_CHARS}): Claude Code dejaría skills sin descripción")
        problems += 1

    # 4. Pares parecidos
    print(f"\nPares con similitud ≥ {THRESHOLD} (palabras de contenido compartidas):")
    vocab = {n: words(d) for n, d in skills.items()}
    pairs = []
    for a, b in itertools.combinations(skills, 2):
        inter = vocab[a] & vocab[b]
        score = len(inter) / len(vocab[a] | vocab[b])
        if score >= THRESHOLD:
            pairs.append((score, a, b, inter))
    if not pairs:
        print("   (ninguno)")
    for score, a, b, inter in sorted(pairs, reverse=True):
        delimited = b in skills[a] or a in skills[b]
        mark = "✅ delimitado" if delimited else "⚠️  sin límite explícito"
        if not delimited:
            problems += 1
        print(f"   {score:.2f}  {a} ↔ {b}  {mark}  [{', '.join(sorted(inter)[:8])}]")

    print(f"\n{'✅ Sin problemas' if problems == 0 else f'⚠️  {problems} avisos'}")
    return 0 if problems == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
