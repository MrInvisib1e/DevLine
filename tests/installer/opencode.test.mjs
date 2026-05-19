import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { readJsonFile } from '../../lib/installer/utils.mjs';
import { installOpenCode } from '../../lib/installer/opencode.mjs';

const tmp = () => mkdtempSync(join(tmpdir(), 'devline-opencode-'));

test('installOpenCode adds devline to plugins array', async () => {
  const dir = tmp();
  try {
    const configFile = join(dir, 'opencode.json');
    writeFileSync(configFile, JSON.stringify({ plugins: [] }));
    await installOpenCode({ dryRun: false, configFile, log: { info: ()=>{}, action: ()=>{}, warn: ()=>{} } });
    const data = readJsonFile(configFile);
    assert.ok(data.plugins.some(p => p.includes('devline')), `plugins should include devline: ${JSON.stringify(data.plugins)}`);
  } finally {
    rmSync(dir, { recursive: true });
  }
});

test('installOpenCode does not duplicate entry', async () => {
  const dir = tmp();
  try {
    const configFile = join(dir, 'opencode.json');
    writeFileSync(configFile, JSON.stringify({ plugins: ['@reydo/devline'] }));
    await installOpenCode({ dryRun: false, configFile, log: { info: ()=>{}, action: ()=>{}, warn: ()=>{} } });
    const data = readJsonFile(configFile);
    assert.equal(data.plugins.filter(p => p.includes('devline')).length, 1);
  } finally {
    rmSync(dir, { recursive: true });
  }
});

test('installOpenCode respects dryRun', async () => {
  const dir = tmp();
  try {
    const configFile = join(dir, 'opencode.json');
    writeFileSync(configFile, JSON.stringify({ plugins: [] }));
    await installOpenCode({ dryRun: true, configFile, log: { info: ()=>{}, action: ()=>{}, warn: ()=>{} } });
    const data = readJsonFile(configFile);
    assert.equal(data.plugins.length, 0);
  } finally {
    rmSync(dir, { recursive: true });
  }
});
