import { existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { appendIfMissing, makeLogger } from './utils.mjs';

/**
 * Register devline with Gemini CLI by appending to ~/.gemini/GEMINI.md.
 * Note: Gemini extensions require the package to be published on npm.
 * @param {object} opts
 * @param {boolean} [opts.dryRun]
 * @param {string} [opts.homeDir]
 * @param {object} [opts.log]
 */
export async function installGemini({ dryRun = false, homeDir, log } = {}) {
  const logger = log ?? makeLogger(dryRun);
  const home = homeDir ?? homedir();
  const geminiDir = join(home, '.gemini');
  const geminiMdPath = join(geminiDir, 'GEMINI.md');

  const block = `\n<!-- devline-start -->\n# devline\nDevline skills are available from the @reydo/devline package.\nInstall: npm install -g @reydo/devline\n<!-- /devline-start -->\n`;

  if (dryRun) {
    logger.info(`Would append devline block to ${geminiMdPath}`);
    return;
  }

  if (!existsSync(geminiDir)) mkdirSync(geminiDir, { recursive: true });
  appendIfMissing(geminiMdPath, block, '<!-- devline-start -->');
  logger.action(`Updated ${geminiMdPath}`);
  logger.warn('Gemini CLI extensions require @reydo/devline to be published on npm.');
  logger.warn('Gemini CLI does not support persistent tool allowlisting. Tool prompts are session-scoped.');
}
