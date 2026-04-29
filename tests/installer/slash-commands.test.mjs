import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { mkdtempSync, rmSync, existsSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { generateSlashCommands } from '../../lib/installer/slash-commands.mjs';

const tmp = () => mkdtempSync(join(tmpdir(), 'devline-slash-'));

const COMMANDS = ['dl-init', 'dl-feature', 'dl-fix', 'dl-review', 'dl-plan', 'dl-sync', 'dl-verify'];

test('generateSlashCommands creates .md file for each command', async () => {
  const dir = tmp();
  await generateSlashCommands({ commandsDir: dir, dryRun: false });
  for (const cmd of COMMANDS) {
    assert.ok(existsSync(join(dir, `${cmd}.md`)), `Missing ${cmd}.md`);
  }
  rmSync(dir, { recursive: true });
});

test('generateSlashCommands file contains command invocation', async () => {
  const dir = tmp();
  await generateSlashCommands({ commandsDir: dir, dryRun: false });
  const content = readFileSync(join(dir, 'dl-init.md'), 'utf8');
  assert.ok(content.includes('dl-init'), 'File should reference the command');
  rmSync(dir, { recursive: true });
});

test('generateSlashCommands respects dryRun', async () => {
  const dir = tmp();
  await generateSlashCommands({ commandsDir: dir, dryRun: true });
  assert.ok(!existsSync(join(dir, 'dl-init.md')), 'dryRun should not create files');
  rmSync(dir, { recursive: true });
});
