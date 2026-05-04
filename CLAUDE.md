# DevFlow

DevFlow is active in this session. Skills are available on demand.

## How to use skills

Load any DevFlow skill when relevant by referencing its path:

| Trigger | Skill file |
|---------|-----------|
| `/init` | `~/.devflow/skills/init/SKILL.md` |
| `/feature <desc>` | `~/.devflow/skills/feature/SKILL.md` |
| `/fix <desc>` | `~/.devflow/skills/fix/SKILL.md` |
| `/review` | `~/.devflow/skills/review/SKILL.md` |
| `/plan <desc>` | `~/.devflow/skills/plan/SKILL.md` |
| `/mem-sync` | `~/.devflow/skills/mem-sync/SKILL.md` |
| `/verify` | `~/.devflow/skills/verify/SKILL.md` |

Shell scripts are in `~/.devflow/bin/` — ensure that directory is on your PATH.

## Iron Law

Before any DevFlow operation: check for `.devflow/` in the git root. If absent, run `/init` first.
