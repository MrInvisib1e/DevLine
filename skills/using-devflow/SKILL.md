---
name: using-devflow
requires: []
triggers_on_complete: []
---

# DevFlow v3

<iron-law>
Before any DevFlow operation: verify `.devflow/` exists in the project root.
If absent: HALT. Print exactly: "DevFlow not initialized. Run /init first."
</iron-law>

DevFlow is active in this session.

## What DevFlow is

A skill library that makes AI behave like a senior engineer.
Your `.devflow/` directory contains a knowledge graph of this codebase.

## Available skills

| Skill | Command | When to use |
|-------|---------|-------------|
| init | `/init` | First-time setup on a new repo |
| feature | `/feature <desc>` | Implement a new feature (full lifecycle) |
| feature quick | `/feature quick <desc>` | Quick feature (no PRD phase) |
| fix | `/fix <desc>` | Debug and fix a bug |
| review | `/review` | Review staged/unstaged changes |
| plan | `/plan <desc>` | Generate implementation plan only |
| mem-sync | `/mem-sync` | Manually sync memory with code |
| verify | `/verify` | Verify work before claiming complete |

## How to use a skill

When the user invokes a skill command, load the corresponding `SKILL.md`:
- `/init` → load `skills/init/SKILL.md`
- `/feature` → load `skills/feature/SKILL.md`
- `/fix` → load `skills/fix/SKILL.md`
- `/review` → load `skills/review/SKILL.md`
- `/plan` → load `skills/plan/SKILL.md`
- `/mem-sync` → load `skills/mem-sync/SKILL.md`
- `/verify` → load `skills/verify/SKILL.md`

Load skills on-demand. Do NOT load all skills at once.

## Key context files

After `/init` is run on this repo, read these for context:
- `.devflow/active/memory.md` — top nodes by PageRank, architecture overview
- `df-explain --rank` — full ranked knowledge graph
- `df-explain <node-id>` — specific node's connections

## If Superpowers is also installed

DevFlow handles: init, feature, fix, review, plan, mem-sync, verify.
Superpowers handles: brainstorming, TDD, systematic debugging, writing plans.
No overlap. Use both freely.
