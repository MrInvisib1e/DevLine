import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { readJsonFile, writeJsonFile, makeLogger } from './utils.mjs';

/**
 * Register @reydo/devline as an OpenCode plugin.
 * @param {object} opts
 * @param {boolean} [opts.dryRun]
 * @param {string} [opts.configFile]  Path to opencode.json (override for testing)
 * @param {object} [opts.log]
 */
export async function installOpenCode({ dryRun = false, configFile, log } = {}) {
  const logger = log ?? makeLogger(dryRun);

  const resolvedConfig = configFile ?? findOpenCodeConfig();
  if (!resolvedConfig) {
    logger.warn('OpenCode config not found. Install OpenCode first, then re-run dl-install.');
    return;
  }

  if (dryRun) {
    logger.info(`Would add @reydo/devline to plugins in ${resolvedConfig}`);
    return;
  }

  const data = readJsonFile(resolvedConfig) ?? {};
  if (!Array.isArray(data.plugins)) data.plugins = [];

  // Remove old devline entries, add fresh one
  data.plugins = data.plugins.filter(p => !String(p).includes('devline') && !String(p).includes('devflow'));
  data.plugins.push('@reydo/devline');

  writeJsonFile(resolvedConfig, data);
  logger.action(`Registered @reydo/devline in ${resolvedConfig}`);
}

/**
 * Find the OpenCode config file by checking standard locations.
 * @returns {string|null}
 */
function findOpenCodeConfig() {
  const home = homedir();
  const candidates = [
    join(home, '.config', 'opencode', 'opencode.json'),
    join(home, '.opencode', 'opencode.json'),
    join(home, 'Library', 'Application Support', 'opencode', 'opencode.json'),
  ];
  return candidates.find(p => existsSync(p)) ?? null;
}
