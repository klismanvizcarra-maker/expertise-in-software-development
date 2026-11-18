#!/usr/bin/env bash
# Fixture: TASK-003 en curso para devops-cloud-agent: Dockerfile que corre como root, sin healthcheck y con un secreto.
set -euo pipefail
T=./.agents/scripts/task.sh

$T add "Endurecer la imagen Docker de la API" "devops-cloud-agent" \
  "Dockerfile multi-etapa que ejecuta como usuario no root, con HEALTHCHECK contra /healthz y sin secretos; JWT_SECRET documentado en .env.example sin valor real; .dockerignore excluye .env y node_modules" >/dev/null
$T start TASK-003 >/dev/null

mkdir -p src
cat > package.json <<'EOF'
{ "name": "api-demo", "type": "module", "scripts": { "start": "node src/server.js", "build": "node -e \"process.exit(0)\"" } }
EOF
cat > src/server.js <<'EOF'
import http from 'node:http';
const port = Number(process.env.PORT || 3000);
http.createServer((req, res) => {
  if (req.url === '/healthz') { res.writeHead(200); return res.end('ok'); }
  res.writeHead(404); res.end();
}).listen(port);
EOF
cat > Dockerfile <<'EOF'
FROM node:24
WORKDIR /app
COPY . .
RUN npm install
ENV JWT_SECRET=supersecreto-cambiar
EXPOSE 3000
CMD ["npm", "start"]
EOF

git add -A
$T commit TASK-003 "anadir dockerfile inicial" feat >/dev/null
