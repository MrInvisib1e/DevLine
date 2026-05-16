# DevFlow

DevFlow is active in this session. Skills are available on demand.

## How to use skills

Load any DevFlow skill when relevant by referencing its path:

| Trigger | Skill file |
|---------|-----------|
| `/df-init` | `~/.devflow/skills/df-init/SKILL.md` |
| `/df-feature <desc>` | `~/.devflow/skills/df-feature/SKILL.md` |
| `/df-fix <desc>` | `~/.devflow/skills/df-fix/SKILL.md` |
| `/df-review` | `~/.devflow/skills/df-review/SKILL.md` |
| `/df-plan <desc>` | `~/.devflow/skills/df-plan/SKILL.md` |
| `/df-sync` | `~/.devflow/skills/df-sync/SKILL.md` |
| `/df-verify` | `~/.devflow/skills/df-verify/SKILL.md` |
| `/df-benchmark` | `~/.devflow/skills/df-benchmark/SKILL.md` |

Shell scripts are in `~/.devflow/bin/` — ensure that directory is on your PATH.

## Iron Law

Before any DevFlow operation: check for `.devflow/` in the git root. If absent, run `/df-init` first.
