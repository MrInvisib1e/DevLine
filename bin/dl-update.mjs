#!/usr/bin/env node

/**
 * dl-update — Update @devline/cli to the latest version
 *
 * Usage: dl-update [--dry-run] [--check]
 */

import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { makeLogger } from '../lib/installer/utils.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const checkOnly = args.includes('--check');

const log = makeLogger(dryRun);

async function main() {
  const require = createRequire(import.meta.url);
  const pkg = require('../package.json');
  const currentVersion = pkg.version;

  log.info(`Current version: ${currentVersion}`);

  // Get latest published version
  let latestVersion;
  try {
    latestVersion = execFileSync('npm', ['view', '@devline/cli', 'version'], { encoding: 'utf8' }).trim();
  } catch (err) {
    log.error('Could not fetch latest version from npm:', err.message);
    log.warn('Check your network connection and that npm is configured correctly.');
    process.exit(1);
  }

  log.info(`Latest version: ${latestVersion}`);

  if (checkOnly) {
    if (currentVersion === latestVersion) {
      log.info('@devline/cli is up to date.');
    } else {
      log.info(`Update available: ${currentVersion} → ${latestVersion}`);
      log.info('Run: dl-update');
    }
    return;
  }

  if (currentVersion === latestVersion) {
    log.info('@devline/cli is already up to date.');
    return;
  }

  log.info(`Updating @devline/cli: ${currentVersion} → ${latestVersion}`);

  if (dryRun) {
    log.info('Would run: npm install -g @devline/cli@latest');
    log.info('Would re-run: dl-install --upgrade');
    return;
  }

  // Install latest
  try {
    execFileSync('npm', ['install', '-g', '@devline/cli@latest'], { stdio: 'inherit' });
  } catch (err) {
    log.error('npm install failed:', err.message);
    log.warn('Try: sudo npm install -g @devline/cli@latest');
    log.warn('Or if using nvm: ensure your nvm node is active.');
    process.exit(1);
  }

  // Re-run platform setup using explicit path — avoids PATH resolution issues
  try {
    execFileSync(process.execPath, [join(__dirname, 'dl-install.mjs'), '--upgrade'], { stdio: 'inherit' });
  } catch {
    log.warn('Could not auto-run dl-install --upgrade. Run it manually to refresh platform configuration.');
  }

  log.action(`Updated @devline/cli: ${currentVersion} → ${latestVersion}`);
}

main().catch(err => {
  console.error('Update failed:', err.message);
  process.exit(1);
});
