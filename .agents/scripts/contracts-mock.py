#!/usr/bin/env python3
"""
Servidor Mock Autónomo desde Contratos API (contracts.json) para SKILL MAESTRO.
Permite desarrollo frontend y móvil 100% desacoplado y en paralelo.

Uso: python3 contracts-mock.py [--port 4000] [--file contracts.json] [--delay 0] [--host 127.0.0.1]
"""

import os
import re
import sys
import json
import time
import argparse
from pathlib import Path
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

def load_contracts(contract_path):
    p = Path(contract_path)
    if not p.is_file():
        # Intentar ruta relativa a la raíz
        root_p = Path(__file__).resolve().parents[2] / contract_path
        if root_p.is_file():
            p = root_p
        else:
            template_p = Path(__file__).resolve().parents[1] / "templates/contracts_template.json"
            if template_p.is_file():
                p = template_p
            else:
                sys.exit(f"❌ Error: Archivo de contratos no encontrado en {contract_path}")

    try:
        with open(p, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data, p
    except Exception as e:
        sys.exit(f"❌ Error al cargar {p}: {e}")

def path_to_regex(route_path):
    # Convertir /users/:id o /users/{id} a regex
    pattern = re.sub(r'\{([a-zA-Z0-9_]+)\}', r'(?P<\1>[^/]+)', route_path)
    pattern = re.sub(r':([a-zA-Z0-9_]+)', r'(?P<\1>[^/]+)', pattern)
    return re.compile(f"^{pattern}$")

class MockServerHandler(BaseHTTPRequestHandler):
    contracts_data = {}
    contract_file_path = ""
    default_delay_ms = 0

    def log_message(self, format, *args):
        # Formato limpio para la consola
        pass

    def send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Mock-Status, X-Requested-With")
        self.send_header("Access-Control-Expose-Headers", "X-Mock-Matched, X-Mock-Latency")

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_cors_headers()
        self.end_headers()

    def handle_request(self, method):
        start_time = time.time()
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        # Health check interno
        if path == "/__health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_cors_headers()
            self.end_headers()
            resp = {
                "status": "ok",
                "service": "skill-maestro-mock-server",
                "endpoints_count": len(self.contracts_data.get("endpoints", [])),
                "contract_file": str(self.contract_file_path)
            }
            self.wfile.write(json.dumps(resp).encode("utf-8"))
            return

        # Inspección de contratos completa
        if path == "/__contracts":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(self.contracts_data).encode("utf-8"))
            return

        # Simulación de latencia de red si aplica
        req_delay = self.default_delay_ms
        if "_delay" in query:
            try:
                req_delay = int(query["_delay"][0])
            except ValueError:
                pass
        if req_delay > 0:
            time.sleep(req_delay / 1000.0)

        # Buscar endpoint coincidente en contracts.json
        base_url = self.contracts_data.get("baseUrl", "").rstrip("/")
        endpoints = self.contracts_data.get("endpoints", [])

        matched_ep = None
        matched_params = {}

        for ep in endpoints:
            if ep.get("method", "").upper() != method:
                continue

            ep_path = ep.get("path", "")
            # Comprobar con y sin baseUrl
            candidate_paths = [ep_path]
            if base_url:
                candidate_paths.append(f"{base_url}{ep_path}")

            for cand in candidate_paths:
                rgx = path_to_regex(cand)
                m = rgx.match(path)
                if m:
                    matched_ep = ep
                    matched_params = m.groupdict()
                    break
            if matched_ep:
                break

        if not matched_ep:
            # 404 No encontrado en los contratos
            self.send_response(404)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_cors_headers()
            self.end_headers()
            err_resp = {
                "error": "NOT_FOUND",
                "message": f"No hay contrato definido para {method} {path}",
                "available_endpoints": [
                    f"{e.get('method')} {e.get('path')}" for e in endpoints
                ]
            }
            self.wfile.write(json.dumps(err_resp, indent=2).encode("utf-8"))
            elapsed = int((time.time() - start_time) * 1000)
            print(f"❌ [MOCK 404] {method} {path} ({elapsed}ms)")
            return

        # Comprobar simulación de código de error vía header o query
        req_status = self.headers.get("X-Mock-Status") or (query.get("_status", [None])[0])
        responses = matched_ep.get("responses", {})

        target_status = 200
        if req_status and str(req_status) in responses:
            target_status = int(req_status)
        else:
            # Priorizar primer 200 o 201 disponible
            if "200" in responses:
                target_status = 200
            elif "201" in responses:
                target_status = 201
            elif responses:
                target_status = int(list(responses.keys())[0])

        # Verificar auth si está activado y el cliente no mandó Authorization
        if matched_ep.get("auth") is True and not self.headers.get("Authorization") and not req_status:
            if "401" in responses:
                target_status = 401

        resp_def = responses.get(str(target_status), {})
        body_data = resp_def.get("body", {})

        elapsed = int((time.time() - start_time) * 1000)

        self.send_response(target_status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("X-Mock-Matched", matched_ep.get("id", "endpoint"))
        self.send_header("X-Mock-Latency", f"{elapsed}ms")
        self.send_cors_headers()
        self.end_headers()

        self.wfile.write(json.dumps(body_data, indent=2).encode("utf-8"))
        status_icon = "✅" if target_status < 400 else "⚠️"
        print(f"{status_icon} [MOCK {target_status}] {method} {path} -> ID: {matched_ep.get('id')} ({elapsed}ms)")

    def do_GET(self):
        self.handle_request("GET")

    def do_POST(self):
        self.handle_request("POST")

    def do_PUT(self):
        self.handle_request("PUT")

    def do_PATCH(self):
        self.handle_request("PATCH")

    def do_DELETE(self):
        self.handle_request("DELETE")

def main():
    parser = argparse.ArgumentParser(description="Servidor Mock API Autónomo desde contracts.json")
    parser.add_argument("--port", type=int, default=4000, help="Puerto HTTP del mock (por defecto 4000)")
    parser.add_argument("--host", default="127.0.0.1", help="Host bind (por defecto 127.0.0.1)")
    parser.add_argument("--file", default="contracts.json", help="Ruta al archivo contracts.json")
    parser.add_argument("--delay", type=int, default=0, help="Latencia de red simulada en milisegundos")
    args = parser.parse_args()

    data, real_path = load_contracts(args.file)
    MockServerHandler.contracts_data = data
    MockServerHandler.contract_file_path = real_path
    MockServerHandler.default_delay_ms = args.delay

    endpoints = data.get("endpoints", [])
    server_address = (args.host, args.port)
    httpd = ThreadingHTTPServer(server_address, MockServerHandler)

    print(f"🚀 SKILL MAESTRO Contracts Mock Server activo en: http://{args.host}:{args.port}")
    print(f"   • Archivo de Contratos: {real_path}")
    print(f"   • Endpoints Cargados:   {len(endpoints)}")
    if args.delay > 0:
        print(f"   • Latencia Simulada:    {args.delay}ms")
    print(f"   • Inspección Swagger:   http://{args.host}:{args.port}/__contracts")
    print(f"   • Health check:         http://{args.host}:{args.port}/__health\n")
    print("Endpoints disponibles:")
    for ep in endpoints:
        auth_tag = "🔒 [AUTH]" if ep.get("auth") else "🌐 [PUB]"
        print(f"   {ep.get('method', 'GET').ljust(6)} {ep.get('path').ljust(25)} {auth_tag} - {ep.get('summary', '')}")
    print("\nPresiona Ctrl+C para detener el servidor.")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nDeteniendo Mock Server...")
        httpd.server_close()

if __name__ == "__main__":
    main()
