import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { mkdtempSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { installCursor } from '../../lib/installer/cursor.mjs';

const tmp = () => mkdtempSync(join(tmpdir(), 'devline-cursor-'));

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
