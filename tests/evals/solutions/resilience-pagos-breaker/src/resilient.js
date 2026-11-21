const TRANSIENT_CODES = new Set(['ETIMEDOUT', 'ECONNRESET', 'ECONNREFUSED']);
export const isTransient = (e) => TRANSIENT_CODES.has(e?.code) || e?.status === 429 || e?.status >= 500;
const circuitOpen = () => Object.assign(new Error('circuit open'), { code: 'CIRCUIT_OPEN' });

export function createResilientCaller({
  timeoutMs = 2000, maxRetries = 3, baseDelayMs = 100, maxDelayMs = 5000,
  failureThreshold = 5, cooldownMs = 30000,
  now = Date.now, sleep = (ms) => new Promise((r) => setTimeout(r, ms)), random = Math.random,
} = {}) {
  let state = 'CLOSED', failures = 0, openedAt = 0;
  const withTimeout = (fn) => new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(Object.assign(new Error('timeout'), { code: 'ETIMEDOUT' })), timeoutMs);
    Promise.resolve().then(fn).then((v) => { clearTimeout(t); resolve(v); }, (e) => { clearTimeout(t); reject(e); });
  });
  const delay = (n) => Math.floor(random() * Math.min(maxDelayMs, baseDelayMs * 2 ** (n - 1)));
  return {
    state: () => state,
    async call(fn) {
      if (state === 'HALF_OPEN') throw circuitOpen();   // ya hay una llamada de prueba en curso
      if (state === 'OPEN') {
        if (now() - openedAt < cooldownMs) throw circuitOpen();
        state = 'HALF_OPEN';
      }
      const trial = state === 'HALF_OPEN';
      for (let attempt = 0; ; attempt++) {
        try {
          const v = await withTimeout(fn);
          failures = 0; state = 'CLOSED';
          return v;
        } catch (e) {
          if (!isTransient(e)) { if (trial) state = 'CLOSED'; throw e; }
          if (!trial && attempt < maxRetries) { await sleep(delay(attempt + 1)); continue; }
          failures++;
          if (trial || failures >= failureThreshold) { state = 'OPEN'; openedAt = now(); }
          throw e;
        }
      }
    },
  };
}
