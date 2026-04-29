import { readFileSync, writeFileSync, renameSync, mkdirSync, existsSync } from 'node:fs';
import { dirname } from 'node:path';

/**
 * Read and parse a JSON file. Returns null if file does not exist.
 * @param {string} filePath
 * @returns {object|null}
 */
export function readJsonFile(filePath) {
  if (!existsSync(filePath)) return null;
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

/**
 * Write data as pretty-printed JSON to filePath. Creates parent directories.
 * Uses atomic write (tmp file + rename).
 * @param {string} filePath
 * @param {object} data
 */
export function writeJsonFile(filePath, data) {
  const dir = dirname(filePath);
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  const tmp = filePath + '.tmp';
  writeFileSync(tmp, JSON.stringify(data, null, 2) + '\n', 'utf8');
  renameSync(tmp, filePath);
}

/**
 * Read JSON file, set key to value, write back. Creates file if missing.
 * @param {string} filePath
 * @param {string} key
 * @param {*} value
 */
export function upsertJsonField(filePath, key, value) {
  const data = readJsonFile(filePath) ?? {};
  data[key] = value;
  writeJsonFile(filePath, data);
}

/**
 * Append content to a text file if marker string is not already present.
 * @param {string} filePath  Path to text file (created if missing)
 * @param {string} content   Content to append
 * @param {string} marker    String to search for before appending
 */
export function appendIfMissing(filePath, content, marker) {
  let existing = '';
  if (existsSync(filePath)) {
    existing = readFileSync(filePath, 'utf8');
  } else {
    const dir = dirname(filePath);
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  }
  if (existing.includes(marker)) return;
  writeFileSync(filePath, existing + content, 'utf8');
}

/**
 * Simple logger with dry-run prefix support.
 * @param {boolean} dryRun
 * @returns {{ info: Function, warn: Function, error: Function, action: Function }}
 */
export function makeLogger(dryRun) {
  const prefix = dryRun ? '[dry-run] ' : '';
  return {
    info: (...args) => console.log(prefix + args.join(' ')),
    warn: (...args) => console.warn('\x1b[33m' + prefix + args.join(' ') + '\x1b[0m'),
    error: (...args) => console.error('\x1b[31m' + prefix + args.join(' ') + '\x1b[0m'),
    action: (...args) => console.log('\x1b[32m' + prefix + '✓ ' + args.join(' ') + '\x1b[0m'),
  };
}
