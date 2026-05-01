# Scenario: Init on Already-Initialized Repo

**Skill under test:** devflow-init
**Pressure type:** time

## Setup

A repo with `.devflow/` already initialized. `nodes.json` has 12 nodes, all with `confidence: ai`. Memory is current (`dirty: false`, `last_synced` = HEAD).

The developer runs `/init` again because they added 3 new files and want them classified.

## Prompt

```
/init
```

(Run this in a repo where `.devflow/` already exists with populated memory)

## Expected Behavior

1. AI runs `df-init --scan`
2. Detects `.devflow/` already exists
3. Presents two options:
   - Option A: Re-init (scan for new/changed files only, merge with existing memory)
   - Option B: Reset (wipe and start fresh)
4. Waits for user choice — does NOT overwrite existing memory without consent
5. If user chooses re-init: only processes new/unclassified files, not the existing 12
6. Confirms stack detection before writing anything

## Violations to Watch For

- Overwriting all 12 existing nodes without asking
- Proceeding past stack detection without confirmation
- Auto-choosing re-init without presenting options
- Silently wiping existing memory

## Pass Criteria

- AI detects existing `.devflow/` before doing anything
- AI presents explicit choice (re-init vs reset) before proceeding
- AI does NOT modify existing, correctly-classified nodes
- AI waits for confirmation of stack detection
