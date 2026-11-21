#!/usr/bin/env bash
# Fixture: TASK-003 en curso para accessibility-testing: formulario de registro con violaciones WCAG 2.1 AA y sin pruebas de accesibilidad.
set -euo pipefail
T=./.agents/scripts/task.sh

$T add "Accesibilidad WCAG 2.1 AA del formulario de registro" "frontend-agent" \
  "public/signup.html sin violaciones WCAG 2.1 AA: idioma de la pagina declarado; cada campo con un label visible asociado (el placeholder y un label oculto no cuentan); el logo con texto alternativo que describa la marca y la imagen decorativa ignorada por lectores de pantalla; encabezados que empiezan por un h1 y sin saltos de nivel; el texto de ayuda (clase hint, con su color en el bloque style de la pagina) con contraste de al menos 4.5:1 sobre el fondo; el envio con un control nativo operable con teclado; test/a11y.test.js con node:test (sin dependencias nuevas: no hay red) que lea el HTML y falle si reaparece cualquiera de estas violaciones; node --test en verde" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p public test
cat > package.json <<'EOF'
{ "name": "signup-demo", "type": "module", "scripts": { "test": "node --test" } }
EOF

cat > public/signup.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Registro - Acme</title>
  <style>
    body { background: #ffffff; color: #222222; font-family: sans-serif; }
    .hint { color: #aaaaaa; font-size: 0.9rem; }
    .btn { background: #0b5fff; color: #ffffff; padding: 8px 16px; cursor: pointer; }
  </style>
</head>
<body>
  <img src="logo.png">
  <h1>Crea tu cuenta</h1>
  <h3>Datos de acceso</h3>
  <form id="signup">
    <input type="email" id="email" name="email" placeholder="Email">
    <input type="password" id="password" name="password" placeholder="Contraseña">
    <p class="hint">Mínimo 12 caracteres</p>
    <img src="divider.png">
    <div class="btn" onclick="document.getElementById('signup').submit()">Crear cuenta</div>
  </form>
</body>
</html>
EOF

cat > test/signup.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

test('la pagina tiene formulario de registro', () => {
  const html = readFileSync(new URL('../public/signup.html', import.meta.url), 'utf8');
  assert.match(html, /id="signup"/);
});
EOF

git add -A
$T commit TASK-003 "anadir formulario de registro inicial" feat >/dev/null
