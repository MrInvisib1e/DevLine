# /dl-sync — Regenerate Memory

Check if memory is stale and regenerate if needed. Called automatically by post-commit hook. Safe to call manually at any time.

**Invoked as:** `/dl-sync`

---

## Gates: 0 (fully autonomous)

---

## Workflow

### Step 1 — Check staleness (T1 Silent)

```bash
LAST=$(python3 -c "import json; print(json.load(open('.devline/config.json')).get('last_synced',''))" 2>/dev/null)
HEAD=$(git rev-parse HEAD 2>/dev/null)
```

| Condition | Action |
|-----------|--------|
| `LAST == HEAD` | T1 Silent exit — memory is current |
| `LAST != HEAD` | Proceed to Step 2 |
| `.devline/config.json` missing | HALT — "Run `/dl-init` first" |
| DEFAULT | Proceed to Step 2 |

### Step 2 — Regenerate (T2 Inform)

Run: `dl-init --write-memory`

Print: "Memory regenerated — last_synced=`{HEAD[:7]}`"

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
| About to run `/dl-review` or `/dl-fix` | Call if `last_synced != HEAD` |
| After major refactor before planning | Manual call |
| Memory looks wrong / stale | Manual call |
| DEFAULT | Trust the post-commit hook |
