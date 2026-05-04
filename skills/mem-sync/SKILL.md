---
name: devflow-mem-sync
description: Verify DevFlow memory is fresh and sync if stale
requires: []
triggers_on_complete: []
---

# Skill: mem-sync

# DevFlow Memory Sync

Verify graph memory is current before the session begins. Invoked automatically by the post-commit hook via `df-sync`. Also safe to call manually before any skill that reads memory.

**When to invoke:** Before any skill that reads `.devflow/active/memory.md`, `nodes.json`, or `edges.json`.

## The Iron Law

```
NEVER SILENTLY CONTINUE WITH STALE MEMORY.
```

---

## Prerequisites

Before running this skill, verify `df-sync` is on PATH:

```bash
which df-sync
```

If not found: tell the developer to install DevFlow (add `bin/` to PATH, or symlink `bin/df-sync` to a directory on PATH) and stop.

---

## Flow

### Step 1 — Check staleness

Read `.devflow/config.json`. Extract `last_synced` and `dirty`.

Run:
```bash
git rev-parse HEAD
```

- If `last_synced == HEAD` and `dirty == false`: memory is current. Exit — nothing to do.
- If `dirty == true` or `last_synced != HEAD`: proceed to Step 2.

### Step 2 — Run df-sync

Run:
```bash
df-sync
```

Capture exit code.

### Step 3 — Verify

Check all required files exist and are valid JSON:

```bash
jq . .devflow/active/memory.json >/dev/null 2>&1
jq . .devflow/active/nodes.json  >/dev/null 2>&1
jq . .devflow/active/edges.json  >/dev/null 2>&1
```

Also verify `.devflow/active/memory.md` exists:
```bash
[ -f .devflow/active/memory.md ]
```

Confirm `config.json` has:
- `dirty == false`
- `last_synced == HEAD SHA` (re-read HEAD after sync)

```bash
head_sha=$(git rev-parse HEAD)
last_synced=$(jq -r '.last_synced' .devflow/config.json)
dirty=$(jq -r '.dirty' .devflow/config.json)
```

If all checks pass: exit success.

### Step 4 — Retry or fail

If Step 3 fails:
- Run `df-sync` once more.
- Re-run the Step 3 checks.
- If still failing: output `[DevFlow] sync failed — memory may be stale` and exit 1.

---

## Error Reference

| Scenario | Response |
|---|---|
| `df-sync` not on PATH | Tell developer to install DevFlow; stop |
| `df-sync` exits non-zero | Retry once (Step 4); fail loudly if still failing |
| `nodes.json` invalid JSON | Log file name, proceed to retry |
| `dirty: true` after sync | Retry once |
| `last_synced != HEAD` after sync | Retry once |
| Still failing after retry | Exit 1 — `[DevFlow] sync failed — memory may be stale` |

---

## Notes

- Never silently continue with stale memory. Always exit 1 if sync cannot be verified.
- If `df-sync` is not on PATH, tell the developer to install DevFlow.
- The post-commit hook calls `df-sync` directly; `mem-sync` is for AI agents to call before reading memory.
- In CI mode (no `.devflow/` directory), `df-sync` exits 0 silently. This skill will see a missing `config.json` and should treat it as "nothing to do" — exit success.

## Guard Rails

1. **Never silently proceed with stale memory.** If memory is stale: T2 Inform that sync is running, run it, continue. Never pretend memory is fresh when it isn't.
2. **No T3 gates.** Sync failures → T2 Inform with error + continue in degraded mode. Do not ask the user what to do. See `skills/_shared.md`.
3. **Degraded mode is safe.** If df-sync fails, proceeding with stale memory is better than blocking. T2 Inform: `[DevFlow] Sync failed — using stale memory (last synced: <sha>).`
4. **Verify after sync.** Confirm `dirty: false` and `last_synced` = HEAD after df-sync.
5. **Reality check.** Memory up to date → T1 Silent. No action needed. Don't run df-sync unnecessarily.

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Memory probably fine" | Check last_synced vs HEAD. Probably ≠ verified. |
| "df-sync slow, skip it" | Stale memory = wrong context = wrong decisions. |
| "Sync after" | After is too late. Sync before reading. |
| "Fresh enough" | Fresh enough ≠ current. Check. |

## Red Flags — STOP

- Reading memory.md without staleness check
- Skipping df-sync when dirty=true
- Skipping df-sync when last_synced ≠ HEAD
- Blocking when df-sync fails instead of T2 Inform + degraded mode

**Stop. Check staleness. Then read.**
