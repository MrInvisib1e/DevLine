---
name: devline-sync
description: Regenerate Devline memory when stale; idempotent and safe to call any time
requires: []
triggers_on_complete: []
---

# /dl-sync — Regenerate Memory

Check if memory is stale and regenerate if needed. Called automatically by post-commit hook. Safe to call manually at any time.

**Invoked as:** `/dl-sync`

---

## Gates: 0 (fully autonomous)

---

## Workflow

### Step 1 — Check staleness (T1 Silent)

```bash
LAST=$(jq -r '.last_synced // ""' .devline/config.json 2>/dev/null)
HEAD=$(git rev-parse HEAD 2>/dev/null)
```

| Condition | Action |
|-----------|--------|
| `LAST == HEAD` | T1 Silent exit — memory is current |
| `LAST != HEAD` | Proceed to Step 2 |
| `.devline/config.json` missing | `HALT. Print exactly: "Run /dl-init first to initialize Devline."` |
| DEFAULT | Proceed to Step 2 |

### Step 2 — Regenerate (T2 Inform)

Run: `dl-init --write-memory`

Print: "Memory regenerated — last_synced=`{HEAD[:7]}`"

### Step 2.5 — Config migrations (T1 Silent, T2 Inform on actual migration)

Apply each migration in the registry from `skills/_shared.md` → "Config Migration". The `review_checks_v2` migration in particular upgrades pre-0.7 bare-string entries to the structured object form that `/dl-review` Phase 2 requires.

Run the canonical migration helper from `_shared.md`. On `migrated` outcome: T2 Inform `[Devline] config.json migrated: review_checks upgraded to v2 (objects)`. On `noop`: T1 Silent.

— because skipping this step leaves `/dl-review` Phase 2 dispatching subagents with one-word prompts, which silently hallucinate the rule. The migration is idempotent and cheap, so it runs on every sync.

### Step 2.7 — Refresh session index (T1 Silent)

Run: `dl-log-index` — rebuilds `.devline/sessions/index.json` from all `session*.jsonl` files. Safe to call on every sync; fast (single-pass parse). — because the index is the only way `/dl-explain` and `/dl-verify` can look up "what happened in feature X" without scanning every JSONL file.

### Step 3 — Verify (T1 Silent)

Confirm `.devline/memory.md` was written (check mtime vs now). If missing: T2 Inform — "memory.md generation failed — check codebase-memory-mcp logs."

---

## Degraded Mode

If `codebase-memory-mcp` is unavailable:
- T2 Inform: "codebase-memory-mcp not available — memory not updated. Run `dl-install --mcp`"
- Continue with stale memory (never block other operations)

---

## When to Call

| Situation | Call |
|-----------|------|
| Post-commit (auto) | Handled by hook — no manual call needed |
| Branch switch (auto) | Handled by post-checkout hook — no manual call needed |
| About to run `/dl-review` or `/dl-fix` | Call if `last_synced != HEAD` |
| After major refactor before planning | Manual call |
| Memory looks wrong / stale | Manual call |
| After successful feature completion | Handled by Phase 6 — no manual call needed |
| DEFAULT | Trust the hooks |

## Red Flags — STOP

- Skipping sync because "memory is probably fine"
- Proceeding with stale memory when sync is available
- Running sync during an active agent dispatch (wait for agent to finish)
- "Memory was just synced" without checking `last_synced` vs HEAD

**Stop. Check staleness. Sync if needed.**
