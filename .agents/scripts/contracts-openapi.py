#!/usr/bin/env python3
"""
Exportador de OpenAPI 3.1.0 / Swagger desde contracts.json para SKILL MAESTRO.
Convierte contratos formales inter-agente en especificaciones OpenAPI 3.1 estándar.

Uso:
  python3 contracts-openapi.py [--file contracts.json] [--output openapi.json]
"""

import os
import re
import sys
import json
import argparse
from pathlib import Path

def infer_schema(val):
    """Infiere el esquema JSON Schema a partir de un valor de ejemplo o anotación."""
    if isinstance(val, dict):
        properties = {}
        for k, v in val.items():
            properties[k] = infer_schema(v)
        return {
            "type": "object",
            "properties": properties
        }
    elif isinstance(val, list):
        item_schema = infer_schema(val[0]) if len(val) > 0 else {"type": "string"}
        return {
            "type": "array",
            "items": item_schema
        }
    elif isinstance(val, bool):
        return {"type": "boolean"}
    elif isinstance(val, int):
        return {"type": "integer"}
    elif isinstance(val, float):
        return {"type": "number"}
    elif isinstance(val, str):
        s = val.lower().strip()
        if "uuid" in s:
            return {"type": "string", "format": "uuid", "example": "123e4567-e89b-12d3-a456-426614174000"}
        if "email" in s:
            return {"type": "string", "format": "email", "example": "usuario@ejemplo.com"}
        if "date" in s or "iso8601" in s or "timestamp" in s:
            return {"type": "string", "format": "date-time", "example": "2026-11-22T10:00:00Z"}
        if "jwt" in s or "token" in s:
            return {"type": "string", "format": "jwt"}
        if "int" in s or "integer" in s:
            return {"type": "integer"}
        if "float" in s or "number" in s or "decimal" in s:
            return {"type": "number"}
        if "bool" in s:
            return {"type": "boolean"}
        return {"type": "string", "description": val}
    else:
        return {"type": "string"}

def normalize_openapi_path(path: str) -> str:
    """Convierte :param a {param}."""
    return re.sub(r':([a-zA-Z0-9_]+)', r'{\1}', path)

def extract_path_params(path: str) -> list:
    """Extrae nombres de parámetros de una ruta {param}."""
    return re.findall(r'\{([a-zA-Z0-9_]+)\}', path)

def contract_to_openapi(data: dict) -> dict:
    title = data.get("title", "API Contracts Specification")
    version = data.get("version", "1.0.0")
    description = data.get("description", "Generated from contracts.json by Skill Maestro")
    base_url = data.get("baseUrl", "/api/v1")

    openapi = {
        "openapi": "3.1.0",
        "info": {
            "title": title,
            "version": version,
            "description": description
        },
        "servers": [
            {
                "url": base_url,
                "description": "Servidor Base"
            }
        ],
        "paths": {},
        "components": {
            "securitySchemes": {
                "BearerAuth": {
                    "type": "http",
                    "scheme": "bearer",
                    "bearerFormat": "JWT",
                    "description": "Autenticación mediante JWT Bearer token"
                }
            },
            "schemas": {}
        }
    }

    # Procesar commonSchemas si existen
    common = data.get("commonSchemas", {})
    for schema_name, schema_def in common.items():
        openapi["components"]["schemas"][schema_name] = infer_schema(schema_def)

    # Procesar endpoints
    endpoints = data.get("endpoints", [])
    for ep in endpoints:
        raw_path = ep.get("path", "/")
        oapi_path = normalize_openapi_path(raw_path)
        method = ep.get("method", "GET").lower()
        op_id = ep.get("id", f"{method}_{oapi_path.replace('/', '_')}")
        summary = ep.get("summary", op_id)
        auth_required = ep.get("auth", False)

        if oapi_path not in openapi["paths"]:
            openapi["paths"][oapi_path] = {}

        operation = {
            "operationId": op_id,
            "summary": summary,
            "responses": {}
        }

        # Tag inferido
        segments = [s for s in raw_path.strip("/").split("/") if s and not s.startswith(":") and not s.startswith("{")]
        if segments:
            operation["tags"] = [segments[0].capitalize()]
        else:
            operation["tags"] = ["Default"]

        # Seguridad
        if auth_required:
            operation["security"] = [{"BearerAuth": []}]

        # Parámetros (Path, Query, Headers)
        params = []
        path_vars = extract_path_params(oapi_path)
        for pv in path_vars:
            params.append({
                "name": pv,
                "in": "path",
                "required": True,
                "schema": {"type": "string"},
                "description": f"Identificador {pv}"
            })

        req_spec = ep.get("request", {})
        query_spec = req_spec.get("query", {})
        for qk, qv in query_spec.items():
            params.append({
                "name": qk,
                "in": "query",
                "required": False,
                "schema": infer_schema(qv),
                "description": f"Parámetro de consulta {qk}"
            })

        header_spec = req_spec.get("headers", {})
        for hk, hv in header_spec.items():
            if hk.lower() in ("content-type", "authorization"):
                continue  # Content-type y Auth se gestionan en OpenAPI por separado
            params.append({
                "name": hk,
                "in": "header",
                "required": False,
                "schema": {"type": "string"},
                "description": f"Encabezado {hk}"
            })

        if params:
            operation["parameters"] = params

        # Request Body
        body_spec = req_spec.get("body")
        if body_spec and method in ("post", "put", "patch", "delete"):
            operation["requestBody"] = {
                "required": True,
                "content": {
                    "application/json": {
                        "schema": infer_schema(body_spec)
                    }
                }
            }

        # Respuestas
        responses = ep.get("responses", {})
        for code_str, resp_val in responses.items():
            resp_desc = resp_val.get("description", f"Respuesta HTTP {code_str}")
            resp_body = resp_val.get("body")
            resp_obj = {"description": resp_desc}
            if resp_body:
                resp_obj["content"] = {
                    "application/json": {
                        "schema": infer_schema(resp_body)
                    }
                }
            operation["responses"][str(code_str)] = resp_obj

        if not operation["responses"]:
            operation["responses"]["200"] = {"description": "Operación completada con éxito"}

        openapi["paths"][oapi_path][method] = operation

    return openapi

def main():
    parser = argparse.ArgumentParser(description="Exporta contracts.json a especificación OpenAPI 3.1.0")
    parser.add_argument("--file", "-f", default=None, help="Ruta al archivo contracts.json")
    parser.add_argument("--output", "-o", default=None, help="Ruta del archivo de salida JSON")
    args = parser.parse_args()

    contract_path = args.file
    if not contract_path:
        p1 = Path.cwd() / "contracts.json"
        p2 = Path(__file__).resolve().parents[1] / "templates/contracts_template.json"
        if p1.is_file():
            contract_path = str(p1)
        elif p2.is_file():
            contract_path = str(p2)
        else:
            sys.exit("❌ Error: No se encontró contracts.json ni plantilla de contratos.")

    p = Path(contract_path)
    if not p.is_file():
        sys.exit(f"❌ Error: Archivo de contratos no encontrado: {contract_path}")

    try:
        with open(p, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        sys.exit(f"❌ Error al parsear JSON en {contract_path}: {e}")

    openapi_doc = contract_to_openapi(data)
    json_str = json.dumps(openapi_doc, indent=2, ensure_ascii=False)

    if args.output:
        out_p = Path(args.output)
        out_p.parent.mkdir(parents=True, exist_ok=True)
        with open(out_p, "w", encoding="utf-8") as f:
            f.write(json_str + "\n")
        print(f"✅ Especificación OpenAPI 3.1 exportada exitosamente a: {args.output}")
    else:
        print(json_str)

if __name__ == "__main__":
    main()
