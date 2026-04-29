import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir, homedir } from 'node:os';
import { join } from 'node:path';
import { detectPlatforms } from '../../lib/installer/detect-platforms.mjs';

const tmp = () => mkdtempSync(join(tmpdir(), 'devline-detect-'));
// Suppress binary detection so tests are deterministic regardless of host environment
const noBinary = () => false;

test('detectPlatforms detects claude via .claude dir', async () => {
  const dir = tmp();
  mkdirSync(join(dir, '.claude'));
  const results = await detectPlatforms({ homeDir: dir, checkBinary: noBinary });
  assert.ok(results.includes('claude'), `Expected claude in ${JSON.stringify(results)}`);
  rmSync(dir, { recursive: true });
});

test('detectPlatforms detects opencode via config file', async () => {
  const dir = tmp();
  mkdirSync(join(dir, '.config', 'opencode'), { recursive: true });
  writeFileSync(join(dir, '.config', 'opencode', 'opencode.json'), '{}');
  const results = await detectPlatforms({ homeDir: dir, checkBinary: noBinary });
  assert.ok(results.includes('opencode'), `Expected opencode in ${JSON.stringify(results)}`);
  rmSync(dir, { recursive: true });
});

test('detectPlatforms returns empty array when nothing detected', async () => {
  const dir = tmp();
  const results = await detectPlatforms({ homeDir: dir, checkBinary: noBinary });
  assert.deepEqual(results, []);
  rmSync(dir, { recursive: true });
});
