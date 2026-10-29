#!/usr/bin/env python3
"""
Análisis estático de las descripciones de las skills (sin llamar a ningún modelo).

- Valida que cases.json solo use skills existentes y que toda skill tenga al menos un caso.
- Comprueba que cada descripción diga cuándo usarla.
- Calcula la similitud entre descripciones (Jaccard de palabras de contenido) y marca
  los pares parecidos que no se delimitan entre sí con un "No usar ... (otra-skill)".

Uso: python3 tests/triggers/lint_descriptions.py [--threshold 0.18]
"""
import itertools
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILLS_DIR = ROOT / ".agents" / "skills"
CASES = Path(__file__).with_name("cases.json")
THRESHOLD = float(sys.argv[sys.argv.index("--threshold") + 1]) if "--threshold" in sys.argv else 0.18

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


def load_skills() -> dict[str, str]:
    skills = {}
    for f in sorted(SKILLS_DIR.glob("*/SKILL.md")):
        m = re.match(r"^---\nname: (.+)\ndescription: (.+)\n---\n", f.read_text())
        if m:
            skills[m.group(1)] = m.group(2)
    return skills


def main() -> int:
    skills = load_skills()
    cases = json.loads(CASES.read_text())["cases"]
    problems = 0

    print(f"Skills: {len(skills)} · Casos: {len(cases)}\n")

    # 1. Referencias de cases.json
    referenced = set()
    for c in cases:
        for key in ("expect", "accept", "forbid"):
            for name in c.get(key, []):
                referenced.add(name)
                if name not in skills:
                    print(f"❌ {c['id']}: '{name}' en {key} no es una skill existente")
                    problems += 1
    expected = {n for c in cases for n in c["expect"]}
    for name in skills:
        if name not in expected:
            print(f"❌ '{name}' no aparece como esperada en ningún caso")
            problems += 1

    # 2. Cláusula de uso
    for name, desc in skills.items():
        if not re.search(r"\bUsar (cuando|siempre|al|para|tras|si)\b", desc):
            print(f"⚠️  '{name}': la descripción no dice cuándo usarla ('Usar cuando…')")
            problems += 1

    # 3. Pares parecidos
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
