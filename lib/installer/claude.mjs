import { existsSync, mkdirSync, symlinkSync, unlinkSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { readJsonFile, writeJsonFile, appendIfMissing, makeLogger } from './utils.mjs';
import { generateSlashCommands } from './slash-commands.mjs';

/**
 * Register devline as a Claude Code plugin.
 * @param {object} ctx  Install context
 * @param {string} ctx.rootDir       Where @devline/cli is installed
 * @param {boolean} ctx.dryRun
 * @param {string} ctx.version
 * @param {string} ctx.skillsDir     Absolute path to skills/
 * @param {string} [ctx.homeDir]     Home directory override (for testing)
 */
export async function installClaude(ctx) {
  const { rootDir, dryRun, version, skillsDir } = ctx;
  const home = ctx.homeDir ?? homedir();
  const log = ctx.log ?? makeLogger(dryRun);

  const claudeDir = join(home, '.claude');
  const cacheDir = join(claudeDir, 'plugins', 'cache', 'local');
  const symlinkPath = join(cacheDir, 'devline');
  const pluginsJsonPath = join(claudeDir, 'plugins', 'installed_plugins.json');
  const claudeMdPath = join(claudeDir, 'CLAUDE.md');
  const commandsDir = join(claudeDir, 'commands');

  if (dryRun) {
    log.info(`Would create symlink: ${symlinkPath} → ${rootDir}`);
    log.info(`Would register in: ${pluginsJsonPath}`);
    log.info(`Would update: ${claudeMdPath}`);
    log.info(`Would generate slash commands in: ${commandsDir}`);
    return;
  }

  // 1. Create symlink in plugin cache
  if (!existsSync(cacheDir)) mkdirSync(cacheDir, { recursive: true });
  if (existsSync(symlinkPath)) unlinkSync(symlinkPath);
  symlinkSync(rootDir, symlinkPath);
  log.action(`Symlinked plugin: ${symlinkPath} → ${rootDir}`);

  // 2. Register in installed_plugins.json
  const pluginsDir = join(claudeDir, 'plugins');
  if (!existsSync(pluginsDir)) mkdirSync(pluginsDir, { recursive: true });
  let pluginsData = readJsonFile(pluginsJsonPath) ?? { plugins: [] };
  if (pluginsData.version === 2 && pluginsData.plugins && typeof pluginsData.plugins === 'object' && !Array.isArray(pluginsData.plugins)) {
    // v2 format: plugins is a dict keyed by "name@marketplace" — preserve existing entries
    delete pluginsData.plugins['devline@local'];
    pluginsData.plugins['devline@local'] = [{
      scope: 'user',
      installPath: symlinkPath,
      version,
      installedAt: new Date().toISOString(),
      lastUpdated: new Date().toISOString(),
    }];
  } else {
    // v1 format: plugins is an array
    if (!Array.isArray(pluginsData.plugins)) pluginsData.plugins = [];
    pluginsData.plugins = pluginsData.plugins.filter(p => p.name !== 'devline');
    pluginsData.plugins.push({ name: 'devline', version, path: symlinkPath });
  }
  writeJsonFile(pluginsJsonPath, pluginsData);
  log.action(`Registered in ${pluginsJsonPath}`);

  // 3. Update ~/.claude/CLAUDE.md with skill table
  const skillBlock = buildSkillTable(skillsDir);
  const marker = '<!-- devline-skills-start -->';
  const endMarker = '<!-- devline-skills-end -->';

  let claudeMdContent = '';
  if (existsSync(claudeMdPath)) {
    claudeMdContent = readFileSync(claudeMdPath, 'utf8');
  }

  if (claudeMdContent.includes(marker)) {
    // Replace existing block
    const regex = new RegExp(`${marker}[\\s\\S]*?${endMarker}`, 'g');
    claudeMdContent = claudeMdContent.replace(regex, `${marker}\n${skillBlock}\n${endMarker}`);
    writeFileSync(claudeMdPath, claudeMdContent, 'utf8');
  } else {
    appendIfMissing(claudeMdPath, `\n${marker}\n${skillBlock}\n${endMarker}\n`, marker);
  }
  log.action(`Updated ${claudeMdPath}`);

  // 4. Generate slash commands
  await generateSlashCommands({ commandsDir, dryRun, log });
}

/**
 * Build the devline skill table for CLAUDE.md injection.
 * @param {string} skillsDir  Absolute path to skills/ directory
 * @returns {string}
 */
function buildSkillTable(skillsDir) {
  const skills = [
    ['dl-init',    'dl-init/SKILL.md',    'Initialize devline in a project'],
    ['dl-feature', 'dl-feature/SKILL.md', 'Start a new feature with devline workflow'],
    ['dl-fix',     'dl-fix/SKILL.md',     'Fix a bug with devline workflow'],
    ['dl-review',  'dl-review/SKILL.md',  'Run a devline code review'],
    ['dl-plan',    'dl-plan/SKILL.md',    'Write an implementation plan'],
    ['dl-sync',    'dl-sync/SKILL.md',    'Sync devline memory'],
    ['dl-verify',  'dl-verify/SKILL.md',  'Verify work is complete'],
  ];

  const rows = skills.map(([cmd, rel, desc]) => {
    const fullPath = join(skillsDir, rel);
    return `| \`/${cmd}\` | ${desc} | \`${fullPath}\` |`;
  }).join('\n');

  return `# Devline Skills\n\n| Command | Description | Skill file |\n|---------|-------------|------------|\n${rows}\n\n## Iron Law\n\nBefore any Devline operation: check for \`.devline/\` in the git root. If absent, run \`/dl-init\` first.`;
}
