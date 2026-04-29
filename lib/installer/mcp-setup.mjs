import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { readJsonFile, writeJsonFile, makeLogger } from './utils.mjs';

const MCP_PACKAGE = 'codebase-memory-mcp';
const MCP_SERVER_NAME = 'codebase-memory';

/**
 * Install codebase-memory-mcp globally and register it with Claude Code and OpenCode.
 * @param {object} opts
 * @param {boolean} [opts.dryRun]
 * @param {string} [opts.homeDir]
 * @param {object} [opts.log]
 */
export async function setupMcp({ dryRun = false, homeDir, log } = {}) {
  const logger = log ?? makeLogger(dryRun);
  const home = homeDir ?? homedir();

  if (dryRun) {
    logger.info(`Would run: npm install -g ${MCP_PACKAGE}`);
    logger.info(`Would register ${MCP_SERVER_NAME} in Claude Code and OpenCode MCP config`);
    return;
  }

  // Install globally
  logger.info(`Installing ${MCP_PACKAGE} globally...`);
  try {
    execFileSync('npm', ['install', '-g', MCP_PACKAGE], { stdio: 'inherit' });
    logger.action(`Installed ${MCP_PACKAGE}`);
  } catch (err) {
    logger.error(`Failed to install ${MCP_PACKAGE}: ${err.message}`);
    logger.warn('Install manually: npm install -g codebase-memory-mcp');
    return;
  }

  // Register with Claude Code
  const claudeMcpPath = join(home, '.claude', 'mcp_servers.json');
  registerMcpServer(claudeMcpPath, logger);

  // Register with OpenCode
  const opencodeMcpPath = join(home, '.config', 'opencode', 'mcp_servers.json');
  if (existsSync(join(home, '.config', 'opencode'))) {
    registerMcpServer(opencodeMcpPath, logger);
  }
}

/**
 * Add codebase-memory MCP server entry to a mcp_servers.json file.
 * @param {string} configPath
 * @param {object} logger
 */
function registerMcpServer(configPath, logger) {
  const data = readJsonFile(configPath) ?? { mcpServers: {} };
  if (!data.mcpServers) data.mcpServers = {};
  data.mcpServers[MCP_SERVER_NAME] = {
    command: 'codebase-memory-mcp',
    args: [],
  };
  writeJsonFile(configPath, data);
  logger.action(`Registered ${MCP_SERVER_NAME} MCP server in ${configPath}`);
}
