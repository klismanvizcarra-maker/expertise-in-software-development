#!/usr/bin/env python3
"""
Seed Data Generator (SKILL MAESTRO)
Generador de datos sintéticos realistas en JSON o SQL para pruebas, testing E2E y desarrollo local.
100% biblioteca estándar de Python 3. Cero dependencias externas.
Autor: Klisman Vizcarra
"""

import sys
import os
import json
import random
import datetime
import hashlib
import uuid
import argparse

FIRST_NAMES = [
    "María", "José", "Carlos", "Sofía", "Alejandro", "Lucía", "Mateo", "Valentina",
    "Álvaro", "Camila", "Kenji", "Chloë", "Jean-Luc", "Aleksei", "Fatima", "Liam",
    "Emma", "Noah", "Olivia", "Héctor", "Inés", "Guillermo", "Pilar", "Ramiro"
]

LAST_NAMES = [
    "Gómez", "Rodríguez", "Peña", "Fernández", "López", "Müller", "Sato", "Évrard",
    "Smirnov", "Al-Mansoor", "Smith", "Johnson", "García", "Martínez", "Vargas",
    "Morales", "Castillo", "Núñez", "Reyes", "Cabrera", "Mendoza", "Silva"
]

ROLES = ["admin", "editor", "user", "viewer"]
CURRENCIES = ["USD", "EUR", "PEN", "GBP", "MXN"]
TX_STATUSES = ["completed", "completed", "completed", "pending", "refunded", "failed"]
PAYMENT_METHODS = ["stripe", "credit_card", "paypal", "bank_transfer"]
LOCALES = ["es-ES", "es-PE", "en-US", "fr-FR", "de-DE", "ja-JP"]
TIMEZONES = ["America/Lima", "Europe/Madrid", "America/New_York", "Europe/Paris", "Asia/Tokyo"]

def clean_ascii(s):
    replacements = {
        'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
        'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u',
        'ñ': 'n', 'Ñ': 'n', 'ü': 'u', 'Ü': 'u', 'ë': 'e',
        'ö': 'o', 'ä': 'a', 'ï': 'i', 'ç': 'c', '-': '', ' ': '.'
    }
    res = s.lower()
    for k, v in replacements.items():
        res = res.replace(k, v)
    return "".join(c for c in res if c.isalnum() or c == '.')

def generate_dataset(count=10, seed=None):
    if seed is not None:
        random.seed(seed)
    
    users = []
    profiles = []
    transactions = []
    
    base_time = datetime.datetime.now(datetime.timezone.utc)
    
    for i in range(1, count + 1):
        uid = str(uuid.uuid4())
        first = random.choice(FIRST_NAMES)
        last = random.choice(LAST_NAMES)
        full_name = f"{first} {last}"
        
        email_prefix = f"{clean_ascii(first)}.{clean_ascii(last)}{i}"
        domain = random.choice(["example.com", "acme.corp", "maestro.dev", "testmail.org"])
        email = f"{email_prefix}@{domain}"
        
        role = "admin" if i == 1 else random.choice(ROLES)
        pass_raw = f"SecretPass{i}!#"
        pass_hash = hashlib.sha256(pass_raw.encode("utf-8")).hexdigest()
        
        days_ago = random.randint(1, 120)
        created_at = (base_time - datetime.timedelta(days=days_ago, minutes=random.randint(0, 1440))).isoformat()
        is_active = random.random() > 0.1
        
        users.append({
            "id": uid,
            "sequential_id": i,
            "name": full_name,
            "email": email,
            "role": role,
            "password_hash": pass_hash,
            "is_active": is_active,
            "created_at": created_at
        })
        
        profiles.append({
            "id": str(uuid.uuid4()),
            "user_id": uid,
            "bio": f"Perfil profesional y verificado de {full_name} para entornos de simulación.",
            "avatar_url": f"https://api.dicebear.com/7.x/avataaars/svg?seed={clean_ascii(first)}_{i}",
            "locale": random.choice(LOCALES),
            "timezone": random.choice(TIMEZONES),
            "updated_at": created_at
        })
        
        # 1-3 transactions per user
        tx_count = random.randint(1, 3)
        for t in range(tx_count):
            amount = round(random.uniform(9.99, 499.99), 2)
            tx_time = (base_time - datetime.timedelta(days=random.randint(0, days_ago), minutes=random.randint(0, 720))).isoformat()
            transactions.append({
                "id": str(uuid.uuid4()),
                "user_id": uid,
                "amount": amount,
                "currency": random.choice(CURRENCIES),
                "status": random.choice(TX_STATUSES),
                "payment_method": random.choice(PAYMENT_METHODS),
                "created_at": tx_time
            })
            
    return {
        "metadata": {
            "generated_at": base_time.isoformat(),
            "generator": "SKILL MAESTRO seed-generator v2.0",
            "author": "Klisman Vizcarra",
            "users_count": len(users),
            "profiles_count": len(profiles),
            "transactions_count": len(transactions)
        },
        "users": users,
        "profiles": profiles,
        "transactions": transactions
    }

def to_sql(data):
    lines = [
        "-- =================================================================",
        "-- Datos Sintéticos Generados por SKILL MAESTRO (seed-generator.py)",
        f"-- Fecha: {data['metadata']['generated_at']}",
        f"-- Usuarios: {data['metadata']['users_count']}, Transacciones: {data['metadata']['transactions_count']}",
        "-- =================================================================",
        "",
        "-- Esquema de tablas",
        "CREATE TABLE IF NOT EXISTS users (",
        "    id VARCHAR(36) PRIMARY KEY,",
        "    sequential_id INTEGER UNIQUE,",
        "    name VARCHAR(120) NOT NULL,",
        "    email VARCHAR(180) UNIQUE NOT NULL,",
        "    role VARCHAR(32) NOT NULL DEFAULT 'user',",
        "    password_hash VARCHAR(64) NOT NULL,",
        "    is_active BOOLEAN NOT NULL DEFAULT TRUE,",
        "    created_at TIMESTAMP WITH TIME ZONE NOT NULL",
        ");",
        "",
        "CREATE TABLE IF NOT EXISTS profiles (",
        "    id VARCHAR(36) PRIMARY KEY,",
        "    user_id VARCHAR(36) REFERENCES users(id) ON DELETE CASCADE,",
        "    bio TEXT,",
        "    avatar_url VARCHAR(255),",
        "    locale VARCHAR(16) DEFAULT 'es-ES',",
        "    timezone VARCHAR(64) DEFAULT 'America/Lima',",
        "    updated_at TIMESTAMP WITH TIME ZONE NOT NULL",
        ");",
        "",
        "CREATE TABLE IF NOT EXISTS transactions (",
        "    id VARCHAR(36) PRIMARY KEY,",
        "    user_id VARCHAR(36) REFERENCES users(id) ON DELETE CASCADE,",
        "    amount NUMERIC(10, 2) NOT NULL,",
        "    currency VARCHAR(8) NOT NULL DEFAULT 'USD',",
        "    status VARCHAR(32) NOT NULL DEFAULT 'completed',",
        "    payment_method VARCHAR(32) NOT NULL DEFAULT 'stripe',",
        "    created_at TIMESTAMP WITH TIME ZONE NOT NULL",
        ");",
        "",
        "-- Inserciones de Usuarios"
    ]
    
    def esc(val):
        if val is None:
            return "NULL"
        if isinstance(val, bool):
            return "TRUE" if val else "FALSE"
        if isinstance(val, (int, float)):
            return str(val)
        s = str(val).replace("'", "''")
        return f"'{s}'"

    for u in data["users"]:
        lines.append(
            f"INSERT INTO users (id, sequential_id, name, email, role, password_hash, is_active, created_at) "
            f"VALUES ({esc(u['id'])}, {esc(u['sequential_id'])}, {esc(u['name'])}, {esc(u['email'])}, {esc(u['role'])}, {esc(u['password_hash'])}, {esc(u['is_active'])}, {esc(u['created_at'])});"
        )
        
    lines.append("")
    lines.append("-- Inserciones de Perfiles")
    for p in data["profiles"]:
        lines.append(
            f"INSERT INTO profiles (id, user_id, bio, avatar_url, locale, timezone, updated_at) "
            f"VALUES ({esc(p['id'])}, {esc(p['user_id'])}, {esc(p['bio'])}, {esc(p['avatar_url'])}, {esc(p['locale'])}, {esc(p['timezone'])}, {esc(p['updated_at'])});"
        )
        
    lines.append("")
    lines.append("-- Inserciones de Transacciones")
    for t in data["transactions"]:
        lines.append(
            f"INSERT INTO transactions (id, user_id, amount, currency, status, payment_method, created_at) "
            f"VALUES ({esc(t['id'])}, {esc(t['user_id'])}, {esc(t['amount'])}, {esc(t['currency'])}, {esc(t['status'])}, {esc(t['payment_method'])}, {esc(t['created_at'])});"
        )

    return "\n".join(lines) + "\n"

def main():
    parser = argparse.ArgumentParser(description="Generador Inteligente de Datos Sintéticos Realistas (SKILL MAESTRO)")
    parser.add_argument("--count", "-n", type=int, default=10, help="Número de registros de usuarios a generar (def: 10)")
    parser.add_argument("--format", "-f", choices=["json", "sql"], default="json", help="Formato de exportación: json o sql (def: json)")
    parser.add_argument("--output", "-o", type=str, default=None, help="Ruta de archivo destino (def: stdout)")
    parser.add_argument("--seed", "-s", type=int, default=None, help="Semilla numérica para generación determinista")
    
    args = parser.parse_args()
    
    if args.count < 1:
        sys.stderr.write("❌ Error: --count debe ser un entero positivo mayor a 0.\n")
        sys.exit(1)
        
    data = generate_dataset(count=args.count, seed=args.seed)
    
    if args.format == "json":
        output_str = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    else:
        output_str = to_sql(data)
        
    if args.output and args.output != "-":
        out_dir = os.path.dirname(os.path.abspath(args.output))
        os.makedirs(out_dir, exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(output_str)
        sys.stderr.write(f"✅ Semillas sintéticas generadas exitosamente ({args.format.upper()}) en: {args.output}\n")
    else:
        sys.stdout.write(output_str)

if __name__ == "__main__":
    main()
