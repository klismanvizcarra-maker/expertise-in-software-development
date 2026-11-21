#!/usr/bin/env node
// Checks deterministas de la eval resilience-pagos-breaker. Se ejecuta desde la raíz del proyecto:
//   node resilience_checks.mjs <timeout|retries|backoff|breaker|mutants>
// Sale con 0 si la implementación de ./src/resilient.js cumple; con 1 si no (y explica por qué).
import { pathToFileURL } from 'node:url';
import { cpSync, mkdtempSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

process.exitCode = 1;
const fail = (msg) => { console.error(msg); process.exit(1); };
const err = (props, msg = 'fallo') => Object.assign(new Error(msg), props);
const base = { timeoutMs: 1000, maxRetries: 0, baseDelayMs: 100, maxDelayMs: 1000, failureThreshold: 1000, cooldownMs: 1000 };
const noSleep = { sleep: async () => {}, random: () => 0.5 };

async function load() {
  return import(pathToFileURL(join(process.cwd(), 'src/resilient.js')).href);
}
async function settle(p) {
  try { return { value: await p }; } catch (e) { return { error: e }; }
}

const checks = {
  async timeout() {
    const { createResilientCaller } = await load();
    const c = createResilientCaller({ ...base, ...noSleep, timeoutMs: 50 });
    const t0 = Date.now();
    const r = await settle(c.call(() => new Promise(() => {})));
    if (!r.error) fail('una llamada que nunca responde no falla');
    if (r.error.code !== 'ETIMEDOUT') fail(`el timeout debe fallar con code ETIMEDOUT (tiene ${r.error.code})`);
    if (Date.now() - t0 > 1000) fail('el timeout tarda mucho más que timeoutMs');
    const fast = await settle(c.call(async () => 'ok'));
    if (fast.value !== 'ok') fail('una llamada rápida debe devolver su resultado');
  },

  async retries() {
    const { createResilientCaller } = await load();
    const sleeps = [];
    const mk = (o = {}) => createResilientCaller({ ...base, maxRetries: 3, random: () => 0.5, sleep: async (ms) => { sleeps.push(ms); }, ...o });
    let n = 0;
    const r1 = await settle(mk().call(async () => { n++; if (n < 3) throw err({ status: 503 }); return 'pagado'; }));
    if (r1.value !== 'pagado' || n !== 3) fail(`un 503 transitorio debe reintentarse hasta tener éxito (intentos: ${n})`);
    if (sleeps.length !== 2) fail(`debe esperar con opts.sleep antes de cada reintento (esperas: ${sleeps.length})`);
    for (const code of ['ECONNRESET', 'ETIMEDOUT']) {
      let k = 0;
      await settle(mk().call(async () => { k++; if (k < 2) throw err({ code }); return 1; }));
      if (k !== 2) fail(`${code} debe reintentarse`);
    }
    let k429 = 0;
    await settle(mk().call(async () => { k429++; if (k429 < 2) throw err({ status: 429 }); return 1; }));
    if (k429 !== 2) fail('un 429 debe reintentarse');
    let m = 0; sleeps.length = 0;
    const r2 = await settle(mk().call(async () => { m++; throw err({ status: 400 }, 'tarjeta invalida'); }));
    if (m !== 1 || !r2.error || r2.error.status !== 400 || sleeps.length) fail('un 400 no se reintenta y se relanza tal cual');
    let q = 0;
    const r3 = await settle(mk({ maxRetries: 2 }).call(async () => { q++; throw err({ status: 502 }); }));
    if (q !== 3 || !r3.error) fail(`con maxRetries 2 debe hacer 3 intentos y fallar (hizo ${q})`);
  },

  async backoff() {
    const { createResilientCaller } = await load();
    const delays = async (random) => {
      const out = [];
      const c = createResilientCaller({ ...base, maxRetries: 8, baseDelayMs: 100, maxDelayMs: 1000, random, sleep: async (ms) => { out.push(ms); } });
      await settle(c.call(async () => { throw err({ status: 503 }); }));
      return out;
    };
    const hi = await delays(() => 0.999);
    const lo = await delays(() => 0);
    if (hi.length !== 8) fail(`se esperaban 8 esperas con maxRetries 8 (hubo ${hi.length})`);
    if (!(hi[3] >= hi[0] * 4)) fail(`el backoff no crece de forma exponencial: ${hi.join(', ')}`);
    if (hi.some((d) => !(d >= 0 && d <= 1000))) fail(`alguna espera supera maxDelayMs o es negativa: ${hi.join(', ')}`);
    if (!(hi[7] > 500)) fail(`el backoff no llega al tope: ${hi.join(', ')}`);
    if (hi.every((d, i) => d === lo[i])) fail('sin jitter: la espera no depende de opts.random');
  },

  async breaker() {
    const { createResilientCaller } = await load();
    let t = 1_000_000;
    const mk = () => createResilientCaller({ ...base, ...noSleep, failureThreshold: 3, cooldownMs: 1000, now: () => t });
    const boom = async () => { throw err({ status: 503 }); };
    // consecutivos: fallo, fallo, éxito, fallo -> sigue cerrado
    const a = mk();
    await settle(a.call(boom)); await settle(a.call(boom)); await a.call(async () => 1); await settle(a.call(boom));
    if (a.state() !== 'CLOSED') fail('un éxito debe reiniciar la cuenta de fallos seguidos');
    // los 4xx no abren el circuito
    const b = mk();
    for (let i = 0; i < 5; i++) await settle(b.call(async () => { throw err({ status: 404 }); }));
    if (b.state() !== 'CLOSED') fail('los 4xx no deben abrir el circuito');
    // se abre y falla rápido sin invocar fn
    const c = mk();
    for (let i = 0; i < 3; i++) await settle(c.call(boom));
    if (c.state() !== 'OPEN') fail(`tras 3 fallos seguidos el circuito debe estar OPEN (está ${c.state()})`);
    let calls = 0;
    const r = await settle(c.call(async () => { calls++; return 1; }));
    if (!r.error || r.error.code !== 'CIRCUIT_OPEN' || calls) fail('con el circuito abierto call() debe rechazar con CIRCUIT_OPEN sin invocar fn');
    // antes del cooldown sigue abierto
    t += 500;
    if (!(await settle(c.call(async () => 1))).error) fail('antes de cooldownMs el circuito sigue abierto');
    // pasado el cooldown: prueba que falla -> se vuelve a abrir
    t += 600;
    calls = 0;
    await settle(c.call(async () => { calls++; throw err({ status: 503 }); }));
    if (calls !== 1 || c.state() !== 'OPEN') fail('pasado cooldownMs se permite una llamada de prueba y, si falla, se vuelve a abrir');
    // nuevo cooldown: prueba que va bien -> se cierra
    t += 1001;
    const ok1 = await settle(c.call(async () => 'ok'));
    if (ok1.value !== 'ok' || c.state() !== 'CLOSED') fail('si la llamada de prueba va bien, el circuito se cierra');
  },

  // Los tests del proyecto deben detectar implementaciones que pierden reintentos o el breaker.
  async mutants() {
    const mutants = {
      'sin reintentos': '{ ...opts, maxRetries: 0 }',
      'sin circuit breaker': '{ ...opts, failureThreshold: Number.MAX_SAFE_INTEGER }',
    };
    for (const [name, override] of Object.entries(mutants)) {
      const dir = mkdtempSync(join(tmpdir(), 'resilience-mutant-'));
      try {
        cpSync(process.cwd(), dir, { recursive: true, filter: (src) => !src.includes('/.git') && !src.includes('/node_modules') });
        renameSync(join(dir, 'src/resilient.js'), join(dir, 'src/resilient.orig.js'));
        writeFileSync(join(dir, 'src/resilient.js'),
          `import * as orig from './resilient.orig.js';\nexport * from './resilient.orig.js';\n` +
          `export function createResilientCaller(opts = {}) { return orig.createResilientCaller(${override}); }\n`);
        const r = spawnSync(process.execPath, ['--test', '--test-timeout=10000'], { cwd: dir, encoding: 'utf8', timeout: 60000 });
        if (r.status === 0) fail(`los tests siguen en verde con una implementación ${name}`);
      } finally {
        rmSync(dir, { recursive: true, force: true });
      }
    }
  },
};

const name = process.argv[2];
if (!checks[name]) fail(`check desconocido: ${name}`);
// Una implementación sin timeout deja promesas colgadas: se corta a los 5 s (150 s para los mutantes).
const hard = setTimeout(() => { console.error('tiempo agotado: alguna llamada no termina'); process.exit(1); }, name === 'mutants' ? 150000 : 5000);
checks[name]().then(() => { clearTimeout(hard); process.exitCode = 0; }, (e) => fail(`error: ${e && e.message}`));
