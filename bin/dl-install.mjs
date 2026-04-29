#!/usr/bin/env node

/**
 * dl-install — Devline installer
 * Registers devline with installed AI platforms (Claude Code, OpenCode, Cursor, Gemini CLI)
 *
 * Usage: dl-install [--dry-run] [--platform <name>] [--install-dir <path>] [--mcp] [--upgrade]
 */

import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { existsSync } from 'node:fs';

import { detectPlatforms } from '../lib/installer/detect-platforms.mjs';
import { installClaude } from '../lib/installer/claude.mjs';
import { installOpenCode } from '../lib/installer/opencode.mjs';
import { installCursor } from '../lib/installer/cursor.mjs';
import { installGemini } from '../lib/installer/gemini.mjs';
import { setupPath } from '../lib/installer/path-setup.mjs';
import { setupMcp } from '../lib/installer/mcp-setup.mjs';
import { makeLogger } from '../lib/installer/utils.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = resolve(__dirname, '..');

// Parse CLI args
const args = process.argv.slice(2);
const flags = {
  dryRun: args.includes('--dry-run'),
  mcp: args.includes('--mcp'),
  upgrade: args.includes('--upgrade'),
  platform: (() => {
    const idx = args.indexOf('--platform');
    if (idx === -1) return 'all';
    const val = args[idx + 1];
    if (!val || val.startsWith('--')) throw new Error('--platform requires a value (claude|opencode|cursor|gemini|all)');
    return val;
  })(),
  installDir: (() => {
    const idx = args.indexOf('--install-dir');
    if (idx === -1) return ROOT_DIR;
    const val = args[idx + 1];
    if (!val || val.startsWith('--')) throw new Error('--install-dir requires a path argument');
    return val;
  })(),
};

const log = makeLogger(flags.dryRun);

async function main() {
  // Load package version
  const require = createRequire(import.meta.url);
  const pkg = require('../package.json');

  log.info(`Devline v${pkg.version} installer`);
  if (flags.dryRun) log.info('DRY RUN — no changes will be made');

  const rootDir = resolve(flags.installDir);
  const skillsDir = join(rootDir, 'skills');
  const binDir = join(rootDir, 'bin');

  // Determine which platforms to install for
  let platforms;
  if (flags.platform === 'all') {
    platforms = await detectPlatforms();
    if (platforms.length === 0) {
      log.warn('No supported AI platforms detected. Install Claude Code, OpenCode, Cursor, or Gemini CLI first.');
      log.warn('Then re-run: dl-install');
      process.exit(0);
    }
    log.info(`Detected platforms: ${platforms.join(', ')}`);
  } else {
    platforms = [flags.platform];
  }

  const ctx = { rootDir, dryRun: flags.dryRun, version: pkg.version, skillsDir, binDir, log };

  // Step 1: PATH setup (only needed for non-npm-global installs)
  await setupPath({ binDir, dryRun: flags.dryRun, log });

  // Step 2: Per-platform registration
  for (const platform of platforms) {
    log.info(`\nConfiguring ${platform}...`);
    switch (platform) {
      case 'claude':   await installClaude({ ...ctx }); break;
      case 'opencode': await installOpenCode({ ...ctx }); break;
      case 'cursor':   await installCursor({ ...ctx }); break;
      case 'gemini':   await installGemini({ ...ctx }); break;
      default:
        log.warn(`Unknown platform: ${platform}. Skipping.`);
    }
  }

  // Step 3: Optional MCP setup
  if (flags.mcp) {
    log.info('\nSetting up codebase-memory MCP server...');
    await setupMcp({ dryRun: flags.dryRun, log });
  }

  // Step 4: Verify
  log.info('\nVerification...');
  const bins = ['dl-explain', 'dl-init', 'dl-check'];
  for (const bin of bins) {
    const binPath = join(binDir, bin);
    if (existsSync(binPath)) {
      log.action(`Found: ${bin}`);
    } else {
      log.warn(`Not found: ${bin} — check that ${binDir} is on your PATH`);
    }
  }

  log.info('\nDevline installation complete!');
  if (!flags.dryRun) {
    log.info('If this is a fresh install, open a new terminal or run:');
    log.info('  source ~/.zshrc   (or ~/.bashrc)');
  }
}

main().catch(err => {
  console.error('Installation failed:', err.message);
  process.exit(1);
});
