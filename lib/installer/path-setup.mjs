import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { appendIfMissing, makeLogger } from './utils.mjs';

const MARKER_START = '# devline';
const MARKER_END = '# /devline';

/**
 * Add binDir to PATH in the user's shell rc file.
 * Detects shell from $SHELL env var. Skips if already configured.
 * @param {{ binDir: string, rcFile?: string, dryRun?: boolean, log?: object }} opts
 */
export async function setupPath({ binDir, rcFile, dryRun = false, log } = {}) {
  const logger = log ?? makeLogger(dryRun);

  // Determine rc file if not provided
  if (!rcFile) {
    rcFile = detectRcFile();
  }

  if (!rcFile) {
    logger.warn('Could not detect shell rc file. Add to PATH manually:');
    logger.warn(`  export PATH="${binDir}:$PATH"`);
    return;
  }

  // Check if already configured
  if (existsSync(rcFile)) {
    const content = readFileSync(rcFile, 'utf8');
    if (content.includes(MARKER_START)) {
      logger.info(`PATH already configured in ${rcFile}`);
      return;
    }
  }

  const block = `\n${MARKER_START}\nexport PATH="${binDir}:$PATH"\n${MARKER_END}\n`;

  if (dryRun) {
    logger.info(`Would append to ${rcFile}:\n${block}`);
    return;
  }

  appendIfMissing(rcFile, block, MARKER_START);
  logger.action(`Added ${binDir} to PATH in ${rcFile}`);
  logger.info(`Run: source ${rcFile}  (or open a new terminal)`);
}

/**
 * Detect the user's shell rc file path.
 * @returns {string|null}
 */
function detectRcFile() {
  const shell = process.env.SHELL ?? '';
  const home = homedir();

  if (shell.includes('zsh')) return join(home, '.zshrc');
  if (shell.includes('bash')) {
    // Prefer .bash_profile on macOS
    const bashProfile = join(home, '.bash_profile');
    const bashRc = join(home, '.bashrc');
    return existsSync(bashProfile) ? bashProfile : bashRc;
  }
  return null;
}
