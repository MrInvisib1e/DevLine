import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { installGemini } from '../../lib/installer/gemini.mjs';

const tmp = () => mkdtempSync(join(tmpdir(), 'devline-gemini-'));

test('installGemini appends to GEMINI.md', async () => {
  const dir = tmp();
  try {
    mkdirSync(join(dir, '.gemini'), { recursive: true });
    const geminiMd = join(dir, '.gemini', 'GEMINI.md');
    writeFileSync(geminiMd, '# Gemini\n');
    await installGemini({ dryRun: false, homeDir: dir, log: { info: ()=>{}, action: ()=>{}, warn: ()=>{} } });
    const content = readFileSync(geminiMd, 'utf8');
    assert.ok(content.includes('<!-- devline-start -->'), 'GEMINI.md should contain devline marker block');
  } finally {
    rmSync(dir, { recursive: true });
  }
});

test('installGemini does not duplicate', async () => {
  const dir = tmp();
  try {
    mkdirSync(join(dir, '.gemini'), { recursive: true });
    const geminiMd = join(dir, '.gemini', 'GEMINI.md');
    // Pre-seed with the marker so appendIfMissing considers it already installed
    writeFileSync(geminiMd, '<!-- devline-start -->\nalready here\n<!-- /devline-start -->\n');
    await installGemini({ dryRun: false, homeDir: dir, log: { info: ()=>{}, action: ()=>{}, warn: ()=>{} } });
    const content = readFileSync(geminiMd, 'utf8');
    // Marker should appear exactly once — no second append
    assert.equal(content.split('<!-- devline-start -->').length - 1, 1);
  } finally {
    rmSync(dir, { recursive: true });
  }
});
