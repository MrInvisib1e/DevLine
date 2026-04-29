import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { execFileSync } from 'node:child_process';

/**
 * Detect which AI platforms are installed on this system.
 * @param {{ homeDir?: string, checkBinary?: (name: string) => boolean }} opts
 * @returns {Promise<string[]>} Array of detected platform names: 'claude', 'opencode', 'cursor', 'gemini'
 */
export async function detectPlatforms({ homeDir = homedir(), checkBinary = hasBinary } = {}) {
  const detected = [];

  // Claude Code: ~/.claude directory OR claude binary on PATH
  if (existsSync(join(homeDir, '.claude')) || checkBinary('claude')) {
    detected.push('claude');
  }

  // OpenCode: opencode binary OR opencode.json config
  if (
    checkBinary('opencode') ||
    existsSync(join(homeDir, '.config', 'opencode', 'opencode.json')) ||
    existsSync(join(homeDir, '.opencode', 'opencode.json'))
  ) {
    detected.push('opencode');
  }

  // Cursor: ~/.cursor directory OR cursor binary
  if (existsSync(join(homeDir, '.cursor')) || checkBinary('cursor')) {
    detected.push('cursor');
  }

  // Gemini CLI: gemini binary
  if (checkBinary('gemini')) {
    detected.push('gemini');
  }

  return detected;
}

/**
 * Check if a binary is available on PATH.
 * @param {string} name
 * @returns {boolean}
 */
function hasBinary(name) {
  try {
    execFileSync('which', [name], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}
