import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { installCursor } from '../../lib/installer/cursor.mjs';

const tmp = () => mkdtempSync(join(tmpdir(), 'devline-cursor-'));
const silentLog = { info: () => {}, warn: () => {}, error: () => {}, action: () => {} };

test('installCursor respects dryRun', async () => {
  const dir = tmp();
  try {
    await installCursor({ dryRun: true, rootDir: dir, homeDir: dir, log: { info: ()=>{}, action: ()=>{}, warn: ()=>{} } });
    // In dry-run, no symlink should be created in homeDir
    assert.ok(!existsSync(join(dir, '.cursor', 'plugins', 'devline')));
  } finally {
    rmSync(dir, { recursive: true });
  }
});

test('installCursor marks devline trusted in existing mcp.json', async () => {
  // Setup: create a temp home with an existing mcp.json
  const home = mkdtempSync(join(tmpdir(), 'devline-cursor-mcp-'));
  const cursorDir = join(home, '.cursor');
  mkdirSync(cursorDir, { recursive: true });
  const mcpPath = join(cursorDir, 'mcp.json');
  writeFileSync(mcpPath, JSON.stringify({ mcpServers: {} }), 'utf8');

  await installCursor({ rootDir: '/fake/root', dryRun: false, homeDir: home, log: silentLog });

  const mcp = JSON.parse(readFileSync(mcpPath, 'utf8'));
  assert.equal(mcp._devline_trusted, true, '_devline_trusted should be set');
  assert.deepEqual(mcp.mcpServers, {}, 'existing fields should be preserved');

  rmSync(home, { recursive: true });
});
