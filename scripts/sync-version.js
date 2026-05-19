#!/usr/bin/env node

/**
 * sync-version.js — Sync version from package.json to all static JSON files.
 * Run automatically via `npm version` lifecycle hook (in package.json "version" script).
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));
const version = pkg.version;

const targets = [
  '.claude-plugin/plugin.json',
  '.cursor-plugin/plugin.json',
  'gemini-extension.json',
];

for (const rel of targets) {
  const filePath = join(root, rel);
  try {
    const data = JSON.parse(readFileSync(filePath, 'utf8'));
    data.version = version;
    writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n');
    console.log(`✓ ${rel} → ${version}`);
  } catch (err) {
    console.error(`✗ ${rel}: ${err.message}`);
    process.exit(1);
  }
}
