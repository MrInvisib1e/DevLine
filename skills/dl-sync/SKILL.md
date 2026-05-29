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

### Step 2.3 — Compact recent-deltas (T1 Silent / T2 Inform)

Count entries in the `recent-deltas` section of `.devline/memory.md`.

| Condition | Action |
|-----------|--------|
| `recent-deltas` has ≤20 entries | T1 Silent — no-op |
| `recent-deltas` has >20 entries | Run compaction script. T2 Inform: `[Devline] recent-deltas compacted: N entries → Architecture` |
| `memory.md` absent | T1 Silent — skip |
| DEFAULT | T1 Silent |

```bash
COMPACT_COUNT=$(python3 - .devline/memory.md << 'PYEOF'
import re, sys, collections

path = sys.argv[1]
try:
    content = open(path).read()
except FileNotFoundError:
    sys.exit(1)

m = re.search(
    r"(<!-- devline:section:recent-deltas -->)(.*?)(<!-- devline:/section:recent-deltas -->)",
    content, re.DOTALL)
if not m:
    sys.exit(1)

deltas_block = m.group(2)
entries = [l.strip() for l in deltas_block.split('\n') if l.strip().startswith('- ')]
if len(entries) <= 20:
    sys.exit(1)

# Extract file mentions as architecture signals
files = collections.Counter()
for e in entries:
    for word in e.split():
        if '/' in word and '.' in word:
            files[word.strip('`.,)')] += 1

summary_lines = [f"- **Hotspot:** `{f}` (changed {c}x in recent features)"
                 for f, c in files.most_common(5) if c > 1]

if summary_lines:
    arch_insert = '\n'.join(summary_lines)
    new_content = re.sub(
        r"(<!-- devline:section:architecture -->.*?)(<!-- devline:/section:architecture -->)",
        lambda mo: mo.group(0).rstrip('\n') + '\n' + arch_insert + '\n',
        content, flags=re.DOTALL)
else:
    new_content = content

# Clear deltas block, keep header
new_deltas = (m.group(1) + "\n## Recent Deltas\n\n"
    "_Appended by Phase 6 of /dl-feature. Compacted into Architecture/Top Nodes by /dl-sync when this block exceeds 20 entries._\n\n"
    + m.group(3))
new_content = new_content[:m.start()] + new_deltas + new_content[m.end():]
open(path, 'w').write(new_content)
print(len(entries))
PYEOF
)
if [ $? -eq 0 ] && [ -n "$COMPACT_COUNT" ]; then
  echo "[Devline] recent-deltas compacted: $COMPACT_COUNT entries → Architecture"
fi
```

### Step 2.5 — Config migrations (T1 Silent, T2 Inform on actual migration)

Apply each migration in the registry from `skills/_shared.md` → "Config Migration". The `review_checks_v2` migration in particular upgrades pre-0.7 bare-string entries to the structured object form that `/dl-review` Phase 2 requires.

Run the canonical migration helper from `_shared.md`. On `migrated` outcome: T2 Inform `[Devline] config.json migrated: review_checks upgraded to v2 (objects)`. On `noop`: T1 Silent.

— because skipping this step leaves `/dl-review` Phase 2 dispatching subagents with one-word prompts, which silently hallucinate the rule. The migration is idempotent and cheap, so it runs on every sync.

### Step 2.6 — Sync decisions.md to MCP ADR store (T1 Silent / T2 Inform / T2 Warn)

Check if `.devline/decisions.md` exists and has content, then sync it to the MCP ADR store via `manage_adr`.

| Condition | Action |
|-----------|--------|
| `decisions.md` absent or empty | T1 Silent — skip |
| `manage_adr` unavailable | T2 Warn: `[Devline] manage_adr unavailable — ADR sync skipped` |
| Content present + manage_adr available | Run sync. T2 Inform: `[Devline] decisions.md synced to MCP ADR store` |
| DEFAULT | T1 Silent — skip |

```bash
if [ -f .devline/decisions.md ] && [ -s .devline/decisions.md ]; then
  MCP_PROJECT=$(echo "$(git rev-parse --show-toplevel 2>/dev/null)" | sed 's|^/||; s|/|-|g')
  DECISIONS_CONTENT=$(python3 -c "import json,sys; print(json.dumps(open('.devline/decisions.md').read()))")
  codebase-memory-mcp cli manage_adr \
    "{\"project\":\"$MCP_PROJECT\",\"action\":\"update\",\"content\":$DECISIONS_CONTENT}" \
    2>/dev/null && \
    echo "[Devline] decisions.md synced to MCP ADR store" || \
    echo "[Devline] manage_adr unavailable — ADR sync skipped"
fi
```

**Why:** ADRs stored in the MCP graph surface through `get_architecture` calls made by all skills — meaning a decision recorded in `decisions.md` becomes visible to every future plan, review, and fix without each skill explicitly reading the file.

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
