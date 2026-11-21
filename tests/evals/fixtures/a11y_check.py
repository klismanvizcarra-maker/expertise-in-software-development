#!/usr/bin/env python3
"""Comprobador determinista de la eval accessibility-wcag-formulario (sin dependencias).

Uso: python3 a11y_check.py <ruta/signup.html>
Sale con 0 si el HTML cumple las reglas WCAG 2.1 AA de la tarea; si no, imprime cada
violación y sale con 1. Lo usan los checks de evals.json y tests/test-scripts.sh.
"""
import re
import sys
from html.parser import HTMLParser

VOID = {"img", "input", "br", "hr", "meta", "link", "source", "area", "col", "embed", "wbr"}


class Doc(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.elements = []      # (tag, attrs, label_depth, text_ref)
        self.stack = []
        self.label_texts = {}   # for-id -> texto
        self.wrapped_inputs = set()
        self.current_label = None
        self.headings = []
        self.style = ""
        self.in_style = False
        self.html_lang = None
        self.heading_text = None

    def handle_starttag(self, tag, attrs):
        a = {k: (v or "") for k, v in attrs}
        if tag == "html":
            self.html_lang = a.get("lang", "").strip()
        if tag == "style":
            self.in_style = True
        if tag == "label":
            self.current_label = {"for": a.get("for", ""), "text": "", "inputs": []}
        if re.fullmatch(r"h[1-6]", tag):
            self.headings.append(int(tag[1]))
        if tag == "input" and self.current_label is not None:
            self.current_label["inputs"].append(a.get("id", "") or f"__anon{len(self.elements)}")
        self.elements.append((tag, a))
        if tag not in VOID:
            self.stack.append(tag)

    def handle_endtag(self, tag):
        if tag == "style":
            self.in_style = False
        if tag == "label" and self.current_label is not None:
            lab = self.current_label
            if lab["for"]:
                self.label_texts[lab["for"]] = self.label_texts.get(lab["for"], "") + lab["text"]
            for i in lab["inputs"]:
                self.wrapped_inputs.add(i)
                self.label_texts[i] = self.label_texts.get(i, "") + lab["text"]
            self.current_label = None
        if tag in self.stack:
            while self.stack and self.stack.pop() != tag:
                pass

    def handle_data(self, data):
        if self.in_style:
            self.style += data
        if self.current_label is not None:
            self.current_label["text"] += data


def luminance(hex_color):
    h = hex_color.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    rgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast(c1, c2):
    l1, l2 = sorted((luminance(c1), luminance(c2)), reverse=True)
    return (l1 + 0.05) / (l2 + 0.05)


def css_color(style, selector, prop):
    m = re.search(re.escape(selector) + r"\s*\{([^}]*)\}", style)
    if not m:
        return None
    d = re.search(r"(?:^|;|\s)" + prop + r"\s*:\s*(#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3})\b", m.group(1))
    return d.group(1) if d else None


def check(html):
    doc = Doc()
    doc.feed(html)
    errors = []
    if not doc.html_lang:
        errors.append("<html> sin atributo lang")

    for tag, a in doc.elements:
        if tag == "input" and a.get("type", "text").lower() not in ("hidden", "submit", "button", "reset", "image"):
            iid = a.get("id", "")
            text = doc.label_texts.get(iid, "").strip() if iid else ""
            if not text:
                errors.append(f"campo {iid or '(sin id)'} sin <label> visible asociado")

    imgs = [(a.get("src", ""), a) for t, a in doc.elements if t == "img"]
    for src, a in imgs:
        decorative = a.get("role") in ("presentation", "none") or a.get("aria-hidden") == "true"
        if "alt" not in a and not decorative:
            errors.append(f"<img src={src}> sin alt")
        elif "logo" in src:
            alt = a.get("alt", "").strip()
            if not alt or re.search(r"\.(png|jpe?g|svg|gif)\b|^(logo|imagen|image)$", alt, re.I):
                errors.append(f"el logo necesita un alt que describa la marca (tiene '{alt}')")
        elif "divider" in src and not decorative and a.get("alt", None) != "":
            errors.append("la imagen decorativa debe llevar alt=\"\" (o role=presentation)")

    prev = 0
    for level in doc.headings:
        if level > prev + 1:
            errors.append(f"salto de encabezado h{prev or '-'} -> h{level}")
        prev = level
    if not doc.headings or doc.headings[0] != 1:
        errors.append("la página debe empezar por un h1")

    native_submit = any(
        (t == "button" and a.get("type", "submit").lower() == "submit")
        or (t == "input" and a.get("type", "").lower() == "submit")
        for t, a in doc.elements)
    if not native_submit:
        errors.append("el envío no es un control nativo (<button type=submit> o <input type=submit>)")
    for t, a in doc.elements:
        if "onclick" in a and t not in ("button", "a", "input"):
            errors.append(f"<{t}> con onclick: no es operable con teclado")

    hint = css_color(doc.style, ".hint", "color")
    bg = css_color(doc.style, "body", "background(?:-color)?") or "#ffffff"
    if not hint:
        errors.append("no se encuentra el color de .hint en <style>")
    elif contrast(hint, bg) < 4.5:
        errors.append(f".hint {hint} sobre {bg}: contraste {contrast(hint, bg):.2f} < 4.5")
    return errors


def mutate(kind, html):
    """Reintroduce una violación concreta (para comprobar que los tests la detectan)."""
    if kind == "alt":       # el logo pierde su alt
        out = re.sub(r"""(<img\b[^>]*src=["'][^"']*logo[^"']*["'][^>]*?)\s+alt=(?:"[^"]*"|'[^']*')""", r"\1", html, count=1)
        if out == html:
            out = re.sub(r"""(<img\b[^>]*?)\s+alt=(?:"[^"]*"|'[^']*')([^>]*src=["'][^"']*logo)""", r"\1\2", html, count=1)
    elif kind == "label":   # los label pasan a texto suelto: los campos quedan sin nombre accesible
        out = re.sub(r"</?label\b[^>]*>", "", html)
    elif kind == "contrast":  # el texto de ayuda vuelve a #aaaaaa
        out = re.sub(r"(\.hint\s*\{[^}]*?(?:^|;|\s)color\s*:\s*)#[0-9a-fA-F]{3,6}", r"\1#aaaaaa", html, count=1, flags=re.M)
    elif kind == "lang":    # se pierde el idioma
        out = re.sub(r"""(<html\b[^>]*?)\s+lang=(?:"[^"]*"|'[^']*')""", r"\1", html, count=1)
    else:
        raise SystemExit(f"mutación desconocida: {kind}")
    if out == html:
        raise SystemExit(f"la mutación {kind} no cambió nada")
    return out


def main():
    if sys.argv[1] == "--mutate":
        path = sys.argv[3]
        html = open(path, encoding="utf-8").read()
        open(path, "w", encoding="utf-8").write(mutate(sys.argv[2], html))
        return 0
    html = open(sys.argv[1], encoding="utf-8").read()
    errors = check(html)
    for e in errors:
        print(f"❌ {e}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
