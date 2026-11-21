import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createResilientCaller } from '../src/resilient.js';
const e503 = () => Object.assign(new Error('x'), { status: 503 });
const quick = { sleep: async () => {}, random: () => 0.5 };
test('timeout', async () => {
  const c = createResilientCaller({ ...quick, timeoutMs: 20, maxRetries: 0 });
  await assert.rejects(c.call(() => new Promise(() => {})), { code: 'ETIMEDOUT' });
});
test('reintenta 503', async () => {
  let n = 0; const c = createResilientCaller({ ...quick, maxRetries: 3 });
  assert.equal(await c.call(async () => { if (++n < 3) throw e503(); return 'ok'; }), 'ok');
});
test('breaker', async () => {
  let t = 0; const c = createResilientCaller({ ...quick, maxRetries: 0, failureThreshold: 2, cooldownMs: 10, now: () => t });
  await assert.rejects(c.call(async () => { throw e503(); }));
  await assert.rejects(c.call(async () => { throw e503(); }));
  assert.equal(c.state(), 'OPEN');
  await assert.rejects(c.call(async () => 1), { code: 'CIRCUIT_OPEN' });
});
