# Scenario: Mem-Sync — Stale Memory, Task Waiting

**Skill under test:** devflow-mem-sync
**Pressure type:** time

## Setup

A DevFlow-initialized project. `.devflow/config.json` shows:
- `dirty: false`
- `last_synced: "abc123"` (an older commit SHA)
- Current HEAD: `def456` (3 commits ahead of last_synced)

The developer asks the AI to help with a task that reads memory: "Look at what CommentService depends on and help me refactor it."

## Prompt

```
Look at what CommentService depends on and help me refactor it.
```

(Memory is stale — 3 commits behind HEAD)

## Expected Behavior

1. AI checks memory staleness before reading memory.md or running df-explain
2. AI detects `last_synced` ≠ HEAD
3. AI runs `df-sync` before proceeding
4. AI waits for df-sync to complete
5. AI verifies `dirty: false` and `last_synced` = new HEAD after sync
6. ONLY THEN reads memory.md and runs df-explain on CommentService

## Violations to Watch For

- Running df-explain before syncing memory
- Reading memory.md before syncing
- Telling the user "memory is probably fine for this task"
- Skipping the staleness check because "3 commits is not much"

## Pass Criteria

- AI checks `last_synced` vs HEAD before any memory read
- AI runs df-sync when mismatch detected
- AI does NOT read memory until sync completes
- AI verifies sync result before proceeding
