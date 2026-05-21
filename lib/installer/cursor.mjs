import { existsSync, mkdirSync, symlinkSync, unlinkSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { makeLogger, readJsonFile, writeJsonFile } from './utils.mjs';

/**
 * Register devline as a Cursor plugin.
 * @param {object} opts
 * @param {string} opts.rootDir       Where @reydo/devline is installed
 * @param {boolean} [opts.dryRun]
 * @param {string} [opts.homeDir]
 * @param {object} [opts.log]
 */
export async function installCursor({ rootDir, dryRun = false, homeDir, log } = {}) {
  if (!rootDir) throw new Error('installCursor: rootDir is required');
  const logger = log ?? makeLogger(dryRun);
  const home = homeDir ?? homedir();
  const cursorPluginsDir = join(home, '.cursor', 'plugins');
  const symlinkPath = join(cursorPluginsDir, 'devline');

  if (dryRun) {
    logger.info(`Would symlink ${symlinkPath} → ${rootDir}`);
    return;
  }

  if (!existsSync(cursorPluginsDir)) mkdirSync(cursorPluginsDir, { recursive: true });
  if (existsSync(symlinkPath)) unlinkSync(symlinkPath);
  symlinkSync(rootDir, symlinkPath);
  logger.action(`Registered Cursor plugin: ${symlinkPath} → ${rootDir}`);

  // Attempt to mark devline trusted in ~/.cursor/mcp.json (if it exists)
  const mcpJsonPath = join(home, '.cursor', 'mcp.json');
  if (existsSync(mcpJsonPath)) {
    try {
      const mcp = readJsonFile(mcpJsonPath) ?? {};
      if (!mcp._devline_trusted) {
        mcp._devline_trusted = true;
        writeJsonFile(mcpJsonPath, mcp);
        logger.action(`Marked devline trusted in ${mcpJsonPath}`);
      }
    } catch {
      logger.warn(`Could not update ${mcpJsonPath} — skipping`);
    }
  }
  logger.warn('Cursor has no user-level shell allowlist. Devline CLI prompts may still appear.');
}
