import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { installClaude } from '../../lib/installer/claude.mjs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const pkg = require('../../package.json');

const tmp = () => mkdtempSync(join(tmpdir(), 'devline-claude-'));

function makeCtx(overrides = {}) {
  const home = tmp();
  mkdirSync(join(home, '.claude', 'plugins', 'cache', 'local'), { recursive: true });
  writeFileSync(join(home, '.claude', 'CLAUDE.md'), '# Claude\n');
  return {
    rootDir: '/fake/devline/root',
    dryRun: false,
    version: pkg.version,
    skillsDir: '/fake/devline/root/skills',
    binDir: '/fake/devline/root/bin',
    homeDir: home,
    ...overrides,
  };
}

test('installClaude registers in installed_plugins.json', async () => {
  const ctx = makeCtx();
  await installClaude(ctx);
  const pluginsFile = join(ctx.homeDir, '.claude', 'plugins', 'installed_plugins.json');
  assert.ok(existsSync(pluginsFile), 'installed_plugins.json should exist');
  const data = JSON.parse(readFileSync(pluginsFile, 'utf8'));
  assert.ok(data.plugins?.some(p => p.name === 'devline'), 'devline should be registered');
  rmSync(ctx.homeDir, { recursive: true });
});

test('installClaude updates CLAUDE.md with skill table', async () => {
  const ctx = makeCtx();
  await installClaude(ctx);
  const claudeMd = readFileSync(join(ctx.homeDir, '.claude', 'CLAUDE.md'), 'utf8');
  assert.ok(claudeMd.includes('devline'), 'CLAUDE.md should reference devline');
  rmSync(ctx.homeDir, { recursive: true });
});

test('installClaude respects dryRun', async () => {
  const ctx = makeCtx({ dryRun: true });
  await installClaude(ctx);
  const pluginsFile = join(ctx.homeDir, '.claude', 'plugins', 'installed_plugins.json');
  assert.ok(!existsSync(pluginsFile), 'dryRun should not create files');
  rmSync(ctx.homeDir, { recursive: true });
});

test('installClaude writes allowedTools to settings.json', async () => {
  const ctx = makeCtx();
  await installClaude(ctx);
  const settingsPath = join(ctx.homeDir, '.claude', 'settings.json');
  assert.ok(existsSync(settingsPath), 'settings.json should exist');
  const settings = JSON.parse(readFileSync(settingsPath, 'utf8'));
  assert.ok(Array.isArray(settings.allowedTools), 'allowedTools should be an array');
  assert.ok(settings.allowedTools.some(e => e.startsWith('Read(')), 'should include Read entry');
  assert.ok(settings.allowedTools.some(e => e.startsWith('Bash(dl-')), 'should include Bash entries');
  rmSync(ctx.homeDir, { recursive: true });
});

test('installClaude merges allowedTools without duplicating', async () => {
  const ctx = makeCtx();
  const settingsPath = join(ctx.homeDir, '.claude', 'settings.json');
  writeFileSync(settingsPath, JSON.stringify({ allowedTools: ['Bash(dl-init*)'] }), 'utf8');
  await installClaude(ctx);
  const settings = JSON.parse(readFileSync(settingsPath, 'utf8'));
  const count = settings.allowedTools.filter(e => e === 'Bash(dl-init*)').length;
  assert.equal(count, 1, 'should not duplicate existing entries');
  rmSync(ctx.homeDir, { recursive: true });
});
