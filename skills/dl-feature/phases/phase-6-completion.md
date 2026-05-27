# Phase 6: Completion

<iron-law>
Load `skills/_shared.md` before proceeding. T1/T2/T3 tiers assumed throughout.
NEVER complete without Phase 5 PASS. NEVER skip memory sync after merge.
</iron-law>

## Pre-flight Checklist (T1 Silent — verify ALL before proceeding)

| Check | Pass? |
|-------|-------|
| Phase 5 review result = PASS | yes/no |
| All slice JSONs have `status: "done"` (none stuck or pending) | yes/no |
| All PRD acceptance criteria verified in Phase 5 | yes/no |
| No uncommitted changes on the feature branch | yes/no |
| plan.md status is up to date | yes/no |

If any item is no: T2 Inform the specific failure. Do not present completion options until resolved.

## Step 1 — Post-completion verification gate (T1/T2)

Run all verification commands from `config.json`:

```bash
# Run test_cmd
<test_cmd from config>

# Run build_cmd if present
<build_cmd if present>

# Run lint_cmd if present
<lint_cmd if present>
```

### Verification Result Table

| Result | Action |
|--------|--------|
| All pass | → proceed to Step 2 |
| test_cmd fails | → route back to Phase 3 with test failure output |
| build_cmd fails | → route back to Phase 3 with build error |
| lint_cmd fails | → T2 Inform, proceed (lint is non-blocking) |
| 3rd failure routed back | → T3 Gate: show all failures, present `dl:choice` for direction |
| DEFAULT | → T2 Inform failures, attempt 1 more sync |

When the 3rd failure row is hit, present this gate:

```dl:choice
question: Verification failed 3 times. How do you want to proceed?
options:
  - label: Route back to Phase 3
    description: Send failures to implementation agents to fix
  - label: Skip failing checks
    description: Mark checks as acceptable and proceed with current state
  - label: Abort feature
    description: Stop the feature run and leave branch as-is
```

CHECKPOINT: "[Devline] Verification complete: all commands passed"

## Step 2 — Memory sync (T1) — incremental append, full-regen on overflow

Append a delta entry for the just-completed feature into `.devline/memory.md` between the `<!-- devline:section:recent-deltas -->` markers. If the block already has >20 entries after the append, fall through to a full regeneration (`dl-init --write-memory`) so the deltas get compacted into the canonical Architecture / Top Nodes sections on the next graph build.

```bash
MEMORY=.devline/memory.md
FEATURE_SLUG=<feature-slug>
FILES_CHANGED=$(git diff --name-only "$(git merge-base HEAD main)..HEAD" | wc -l | tr -d ' ')
NEW_SYMBOLS=$(git diff "$(git merge-base HEAD main)..HEAD" | grep -E '^\+(export|public|class |def |func |fn )' | head -10 | sed 's/^+//' | tr '\n' ',' | sed 's/,$//')
DATE=$(date -u +%Y-%m-%d)
ENTRY="- ${DATE} · ${FEATURE_SLUG} · files: ${FILES_CHANGED} · new symbols: ${NEW_SYMBOLS:-none}"

# Insert ENTRY before the recent-deltas close marker.
# Python prints exactly one token to stdout: "MISSING" or "OK <count>".
RESULT=$(python3 - "$MEMORY" "$ENTRY" << 'PYEOF'
import re, sys
path, entry = sys.argv[1], sys.argv[2]
text = open(path).read()
marker_open  = "<!-- devline:section:recent-deltas -->"
marker_close = "<!-- devline:/section:recent-deltas -->"
if marker_open not in text or marker_close not in text:
    print("MISSING")
    sys.exit(0)
before, rest = text.split(marker_close, 1)
new_text = before.rstrip() + "\n" + entry + "\n" + marker_close + rest
open(path, "w").write(new_text)
block = re.search(re.escape(marker_open) + r"(.*?)" + re.escape(marker_close), new_text, re.DOTALL).group(1)
n = sum(1 for line in block.splitlines() if line.startswith("- "))
print(f"OK {n}")
PYEOF
)

case "$RESULT" in
  MISSING)
    dl-init --write-memory
    T2_REASON="full regen (markers absent — rebuilding canonical structure)"
    ;;
  OK\ *)
    COUNT=${RESULT#OK }
    if [ "$COUNT" -gt 20 ]; then
      dl-init --write-memory
      T2_REASON="full regen (delta block compacted at ${COUNT} entries)"
    else
      T2_REASON="incremental append (${COUNT} deltas pending compaction)"
    fi
    ;;
  *)
    dl-init --write-memory
    T2_REASON="full regen (unexpected helper output — defensive fallback)"
    ;;
esac
```

T2 Inform: `[Devline] Memory synced: <sha> (${T2_REASON})`

— because regenerating memory.md from a graph rebuild on every feature is expensive (the graph walk dominates) and unnecessary when the delta is one feature; an append-mostly model with periodic compaction matches how the memory is actually read.

## Step 3 — Archive plan (T1)

Move the active plan to archive:
```bash
mv .devline/plans/<plan-slug>/ .devline/plans/archive/<plan-slug>-$(date +%Y%m%d)/
```

T2 Inform: `[Devline] Plan archived: <plan-slug>`

## Step 4 — T3: Completion strategy gate

Determine base branch:
```bash
BASE=$(git merge-base HEAD main 2>/dev/null && echo main || echo master)
```

Present a `dl:choice` gate:

```dl:choice
question: Feature complete. All tests pass. How do you want to integrate this work?
options:
  - label: Merge now
    description: git merge --no-ff into {base} immediately
  - label: Open a PR
    description: Push branch and create PR via gh pr create
  - label: Keep branch
    description: Stay on current branch for later review or merge
  - label: Discard
    description: Delete the feature branch (requires confirmation)
default: Merge now
```

Wait for response. Then execute the chosen option per the Completion Option Table below.

### Completion Option Table

| Choice | Action |
|--------|--------|
| A | `git checkout <base> && git pull && git merge --no-ff feature/<name> -m "feat: <feature-name>"` → run tests → cleanup |
| B | `git push -u origin feature/<name>` → `gh pr create --title "<feature-name>" --body "Closes #<issue>"` |
| C | T2 Inform: `[Devline] Branch kept: <branch-name>. PR or merge when ready.` |
| D | Show-then-act: "You are about to force-delete branch `feature/<name>`. Commits ahead of base: [N]. Uncommitted changes: [none/list]. Type 'discard' to confirm, or Enter to cancel." → on typed 'discard': `git checkout <base> && git branch -D feature/<name>` → cleanup |
| DEFAULT | → A (merge now) |

## Step 5 — Record completion (T1)

Append to `.devline/history.json` (create if doesn't exist):

```json
{
  "feature": "<feature-name>",
  "branch": "<branch-name>",
  "completed_at": "<ISO timestamp>",
  "completion_strategy": "<A|B|C|D>",
  "plan_archived": "<archive-path>"
}
```

CHECKPOINT: "[Devline] Feature <name> complete and recorded"

CHECKPOINT: "[Devline] Phase 6 complete: memory synced, plan archived, feature complete"

## Step 6 — Cleanup (T1)

### Worktree + Branch Cleanup

| Choice | Worktree | Branch | Action |
|--------|----------|--------|--------|
| A (Merge) | Remove | Delete | `git worktree remove <path>` → `git branch -d feature/<name>` |
| B (PR) | Keep | Keep | Worktree preserved for PR review |
| C (Keep) | Keep | Keep | No cleanup |
| D (Discard) | Remove | Force-delete | `git worktree remove <path>` → `git branch -D feature/<name>` |

### Artifact Cleanup (T1 Silent)

Clean up stale session artifacts and refresh the session index:
```bash
# Remove session logs older than 30 days
find .devline/sessions/ -name "*.jsonl" -mtime +30 -delete 2>/dev/null || true

# Remove archived plans older than 90 days
find .devline/plans/archive/ -maxdepth 1 -mtime +90 -type d -exec rm -rf {} + 2>/dev/null || true

# Rebuild sessions/index.json so the just-completed feature is discoverable
dl-log-index 2>/dev/null || true
```

T1 Silent — cleanup only.

## Step 7 — Clean up active symlink (T1)

Remove the active plan symlink if it points to the now-archived plan.
```bash
ls -la .devline/plans/active 2>/dev/null || true
```

T1 Silent — cleanup only.
