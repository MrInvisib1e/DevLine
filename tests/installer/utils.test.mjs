import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { readJsonFile, writeJsonFile, upsertJsonField, appendIfMissing } from '../../lib/installer/utils.mjs';

const tmp = () => mkdtempSync(join(tmpdir(), 'devline-test-'));

test('readJsonFile parses valid JSON file', () => {
  const dir = tmp();
  const file = join(dir, 'test.json');
  writeFileSync(file, JSON.stringify({ foo: 'bar' }));
  const result = readJsonFile(file);
  assert.deepEqual(result, { foo: 'bar' });
  rmSync(dir, { recursive: true });
});

test('readJsonFile returns null for missing file', () => {
  const result = readJsonFile('/nonexistent/path/file.json');
  assert.equal(result, null);
});

test('writeJsonFile writes pretty-printed JSON', () => {
  const dir = tmp();
  const file = join(dir, 'out.json');
  writeJsonFile(file, { hello: 'world' });
  const raw = readFileSync(file, 'utf8');
  assert.ok(raw.includes('\n'));
  assert.deepEqual(JSON.parse(raw), { hello: 'world' });
  rmSync(dir, { recursive: true });
});

test('upsertJsonField adds new key', () => {
  const dir = tmp();
  const file = join(dir, 'config.json');
  writeFileSync(file, JSON.stringify({ existing: 1 }));
  upsertJsonField(file, 'newKey', 'newValue');
  const result = readJsonFile(file);
  assert.equal(result.existing, 1);
  assert.equal(result.newKey, 'newValue');
  rmSync(dir, { recursive: true });
});

test('upsertJsonField updates existing key', () => {
  const dir = tmp();
  const file = join(dir, 'config.json');
  writeFileSync(file, JSON.stringify({ key: 'old' }));
  upsertJsonField(file, 'key', 'new');
  assert.equal(readJsonFile(file).key, 'new');
  rmSync(dir, { recursive: true });
});

test('appendIfMissing adds content when marker absent', () => {
  const dir = tmp();
  const file = join(dir, 'file.md');
  writeFileSync(file, '# Existing\n');
  appendIfMissing(file, '# New Section\ncontent here\n', '# New Section');
  const content = readFileSync(file, 'utf8');
  assert.ok(content.includes('# New Section'));
  rmSync(dir, { recursive: true });
});

test('appendIfMissing skips when marker present', () => {
  const dir = tmp();
  const file = join(dir, 'file.md');
  writeFileSync(file, '# Existing\n# New Section\nalready here\n');
  appendIfMissing(file, '# New Section\ncontent here\n', '# New Section');
  const content = readFileSync(file, 'utf8');
  assert.equal(content.split('# New Section').length - 1, 1); // only one occurrence
  rmSync(dir, { recursive: true });
});
