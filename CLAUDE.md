# Devline

Devline is active in this session. Skills are available on demand.

## How to use skills

Load any Devline skill when relevant by referencing its path:

| Trigger | Skill file |
|---------|-----------|
| `/dl-init` | `~/.devline/skills/dl-init/SKILL.md` |
| `/dl-feature <desc>` | `~/.devline/skills/dl-feature/SKILL.md` |
| `/dl-fix <desc>` | `~/.devline/skills/dl-fix/SKILL.md` |
| `/dl-review` | `~/.devline/skills/dl-review/SKILL.md` |
| `/dl-plan <desc>` | `~/.devline/skills/dl-plan/SKILL.md` |
| `/dl-sync` | `~/.devline/skills/dl-sync/SKILL.md` |
| `/dl-verify` | `~/.devline/skills/dl-verify/SKILL.md` |
| `/dl-benchmark` | `~/.devline/skills/dl-benchmark/SKILL.md` |

Shell scripts are in `~/.devline/bin/` — ensure that directory is on your PATH.

## Iron Law

Before any Devline operation: check for `.devline/` in the git root. If absent, run `/dl-init` first.
