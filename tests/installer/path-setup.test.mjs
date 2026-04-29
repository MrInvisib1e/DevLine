import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setupPath } from '../../lib/installer/path-setup.mjs';

const tmp = () => mkdtempSync(join(tmpdir(), 'devline-path-'));

test('setupPath appends PATH export to rc file', async () => {
  const dir = tmp();
  const rcFile = join(dir, '.zshrc');
  writeFileSync(rcFile, '# existing content\n');
  await setupPath({ binDir: '/usr/local/lib/devline/bin', rcFile, dryRun: false });
  const content = readFileSync(rcFile, 'utf8');
  assert.ok(content.includes('export PATH="/usr/local/lib/devline/bin:$PATH"'));
  assert.ok(content.includes('# devline'));
  rmSync(dir, { recursive: true });
});

test('setupPath skips if PATH already configured', async () => {
  const dir = tmp();
  const rcFile = join(dir, '.zshrc');
  writeFileSync(rcFile, '# devline\nexport PATH="/usr/local/lib/devline/bin:$PATH"\n# /devline\n');
  await setupPath({ binDir: '/usr/local/lib/devline/bin', rcFile, dryRun: false });
  const content = readFileSync(rcFile, 'utf8');
  // Should not appear twice
  assert.equal(content.split('# devline').length - 1, 1);
  rmSync(dir, { recursive: true });
});

test('setupPath respects dryRun flag', async () => {
  const dir = tmp();
  const rcFile = join(dir, '.zshrc');
  writeFileSync(rcFile, '# existing\n');
  await setupPath({ binDir: '/usr/local/lib/devline/bin', rcFile, dryRun: true });
  const content = readFileSync(rcFile, 'utf8');
  assert.ok(!content.includes('export PATH'), 'dryRun should not modify file');
  rmSync(dir, { recursive: true });
});
