#!/usr/bin/env python3
"""
Simulador de Carga y Resiliencia HTTP para SKILL MAESTRO.
Permite evaluar concurrencia, latencias p50/p95/p99 y resiliencia sin dependencias externas.

Uso:
  python3 stress-test.py --url http://127.0.0.1:4200/api/status -c 5 -n 50
"""

import sys
import time
import json
import argparse
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import Counter

def percentile(sorted_list, pct):
    if not sorted_list:
        return 0.0
    k = (len(sorted_list) - 1) * (pct / 100.0)
    f = int(k)
    c = min(f + 1, len(sorted_list) - 1)
    d = k - f
    return sorted_list[f] + d * (sorted_list[c] - sorted_list[f])

def send_request(url, method, timeout, headers=None, body=None):
    req = Request(url, method=method)
    if headers:
        for k, v in headers.items():
            req.add_header(k, v)
    else:
        req.add_header("User-Agent", "SkillMaestro-StressTest/2.1.0")

    t0 = time.perf_counter()
    try:
        with urlopen(req, data=body, timeout=timeout) as resp:
            _ = resp.read()
            lat_ms = (time.perf_counter() - t0) * 1000.0
            return resp.status, lat_ms, None
    except HTTPError as e:
        lat_ms = (time.perf_counter() - t0) * 1000.0
        return e.code, lat_ms, None
    except URLError as e:
        lat_ms = (time.perf_counter() - t0) * 1000.0
        return 0, lat_ms, f"URLError: {e.reason}"
    except Exception as e:
        lat_ms = (time.perf_counter() - t0) * 1000.0
        return 0, lat_ms, f"Error: {str(e)}"

def run_stress_test(url, concurrency, total_requests, method="GET", timeout=5.0):
    latencies = []
    status_codes = Counter()
    errors = Counter()

    t_start = time.perf_counter()

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [
            executor.submit(send_request, url, method, timeout)
            for _ in range(total_requests)
        ]
        for f in as_completed(futures):
            status, lat, err = f.result()
            latencies.append(lat)
            if err:
                errors[err] += 1
            else:
                status_codes[status] += 1

    total_time = time.perf_counter() - t_start
    latencies.sort()

    successful_reqs = sum(c for s, c in status_codes.items() if 200 <= s < 400)
    failed_reqs = total_requests - successful_reqs
    rps = total_requests / total_time if total_time > 0 else 0.0

    avg_lat = sum(latencies) / len(latencies) if latencies else 0.0
    p50_lat = percentile(latencies, 50)
    p90_lat = percentile(latencies, 90)
    p95_lat = percentile(latencies, 95)
    p99_lat = percentile(latencies, 99)
    min_lat = latencies[0] if latencies else 0.0
    max_lat = latencies[-1] if latencies else 0.0

    return {
        "url": url,
        "method": method,
        "concurrency": concurrency,
        "total_requests": total_requests,
        "successful_requests": successful_reqs,
        "failed_requests": failed_reqs,
        "duration_seconds": round(total_time, 3),
        "requests_per_second": round(rps, 2),
        "latencies_ms": {
            "min": round(min_lat, 2),
            "avg": round(avg_lat, 2),
            "p50": round(p50_lat, 2),
            "p90": round(p90_lat, 2),
            "p95": round(p95_lat, 2),
            "p99": round(p99_lat, 2),
            "max": round(max_lat, 2)
        },
        "status_codes": dict(status_codes),
        "errors": dict(errors)
    }

def print_text_report(stats):
    print("=" * 64)
    print("⚡ SKILL MAESTRO — Simulador de Carga y Resiliencia HTTP")
    print("=" * 64)
    print(f"🎯 URL Destino   : {stats['url']}")
    print(f"🔄 Método        : {stats['method']}")
    print(f"👥 Concurrencia  : {stats['concurrency']} workers")
    print(f"📊 Peticiones    : {stats['total_requests']} totales")
    print(f"⏱️  Tiempo Total  : {stats['duration_seconds']}s")
    print(f"🚀 Rendimiento   : {stats['requests_per_second']} req/s")
    print("-" * 64)
    print("📈 Distribución de Latencia (ms):")
    print(f"   Min      : {stats['latencies_ms']['min']:>8.2f} ms")
    print(f"   Avg      : {stats['latencies_ms']['avg']:>8.2f} ms")
    print(f"   p50      : {stats['latencies_ms']['p50']:>8.2f} ms")
    print(f"   p90      : {stats['latencies_ms']['p90']:>8.2f} ms")
    print(f"   p95      : {stats['latencies_ms']['p95']:>8.2f} ms")
    print(f"   p99      : {stats['latencies_ms']['p99']:>8.2f} ms")
    print(f"   Max      : {stats['latencies_ms']['max']:>8.2f} ms")
    print("-" * 64)
    print("📋 Códigos de Estado:")
    for code, count in stats["status_codes"].items():
        print(f"   HTTP {code:<4} : {count:>5} peticiones")
    if stats["errors"]:
        print("⚠️  Errores de Red / Timeout:")
        for err, count in stats["errors"].items():
            print(f"   {err:<24} : {count:>5}")
    print("=" * 64)
    if stats["failed_requests"] == 0:
        print("✅ Resiliencia Aprobada: 100% de peticiones exitosas (0 fallos)")
    else:
        fail_pct = (stats["failed_requests"] / stats["total_requests"]) * 100.0
        print(f"⚠️  Tasa de Fallo: {fail_pct:.1f}% ({stats['failed_requests']} fallidas)")

def main():
    parser = argparse.ArgumentParser(description="Simulador de Carga y Resiliencia HTTP (task.sh stress)")
    parser.add_argument("pos_url", nargs="?", default=None, help="URL a evaluar")
    parser.add_argument("--url", "-u", default=None, help="URL a evaluar")
    parser.add_argument("--concurrency", "-c", type=int, default=5, help="Nivel de concurrencia (default: 5)")
    parser.add_argument("--requests", "-n", type=int, default=20, help="Total de peticiones (default: 20)")
    parser.add_argument("--method", "-m", default="GET", help="Método HTTP (default: GET)")
    parser.add_argument("--timeout", "-t", type=float, default=5.0, help="Timeout por petición en segundos (default: 5.0)")
    parser.add_argument("--json", action="store_true", help="Salida en formato JSON estructurado")
    parser.add_argument("--fail-threshold", type=float, default=0.0, help="Porcentaje máximo de fallos tolerado (0.0 a 100.0)")
    args = parser.parse_args()

    target_url = args.url or args.pos_url
    if not target_url:
        target_url = "http://127.0.0.1:4200/api/status"

    if args.concurrency <= 0 or args.requests <= 0:
        sys.exit("❌ Error: concurrencia y peticiones deben ser mayores a 0.")

    stats = run_stress_test(
        url=target_url,
        concurrency=args.concurrency,
        total_requests=args.requests,
        method=args.method.upper(),
        timeout=args.timeout
    )

    if args.json:
        print(json.dumps(stats, indent=2))
    else:
        print_text_report(stats)

    fail_rate = (stats["failed_requests"] / stats["total_requests"]) * 100.0
    if fail_rate > args.fail_threshold:
        sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
