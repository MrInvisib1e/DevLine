import { writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { makeLogger } from './utils.mjs';

// The Claude Code slash commands to generate
const COMMANDS = [
  { name: 'dl-init',    description: 'Initialize devline in the current project' },
  { name: 'dl-feature', description: 'Start a new feature with devline workflow' },
  { name: 'dl-fix',     description: 'Fix a bug with devline workflow' },
  { name: 'dl-review',  description: 'Run a devline code review' },
  { name: 'dl-plan',    description: 'Write an implementation plan with devline' },
  { name: 'dl-sync',    description: 'Sync devline memory with current codebase' },
  { name: 'dl-verify',  description: 'Verify work is complete and correct' },
];

/**
 * Generate Claude Code slash command .md files.
 * @param {{ commandsDir?: string, dryRun?: boolean, log?: object }} opts
 */
export async function generateSlashCommands({ commandsDir, dryRun = false, log } = {}) {
  const logger = log ?? makeLogger(dryRun);
  const dir = commandsDir ?? join(homedir(), '.claude', 'commands');

  if (!dryRun && !existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }

  for (const { name, description } of COMMANDS) {
    const filePath = join(dir, `${name}.md`);
    const content = `---\ndescription: ${description}\n---\n# ${name}\n\n${description}\n\nRun: \`${name}\`\n`;

    if (dryRun) {
      logger.info(`Would create ${filePath}`);
      continue;
    }

    writeFileSync(filePath, content, 'utf8');
    logger.action(`Created slash command: ${filePath}`);
  }
}
