---
name: devflow-fix
description: Fix a bug using memory-aware hypothesis-driven debugging
requires: [mem-sync]
triggers_on_complete: [verify]
---

# Fix Skill

Trigger: `/fix "<description of what's broken>"`

Examples:
- `/fix "comments endpoint returns 500 on empty body"`
- `/fix "UserService throws NullReferenceException on login"`

---

## The Iron Law

```
HYPOTHESIS BEFORE CODE. ALWAYS. — because reading code without a hypothesis leads to undirected exploration that misses root causes.
```

---

## Pre-flight Checks

Run BEFORE any reasoning or file reading:

### 1. Memory staleness

Read `.devflow/config.json`. Check two conditions:

```bash
git rev-parse HEAD   # get current HEAD SHA
```

- If `dirty` field is `true`, OR
- If `last_synced` value ≠ current HEAD SHA

Then run:

```bash
df-sync
```

Print: `[DevFlow] Memory was stale — synced to <sha> before proceeding.`

### 2. Conflict check

Check if `.devflow/active/graph_conflicts.json` exists:

```bash
ls .devflow/active/graph_conflicts.json 2>/dev/null
```

If it exists: print all conflicted node IDs from the file, then print:

```
[DevFlow] Unresolved graph conflicts detected. Run df-resolve before proceeding.
Affected nodes: <list node ids>
```

**HALT — do not proceed until developer runs df-resolve.**

---

## Step 1 — Node Inference + Confirmation

Parse the developer's description and identify the most likely node (entity, route, or service).

Print: `[DevFlow] Targeting [<inferred-node>] (<kind>) — <file>.` (T2 Inform)
Run `df-explain <inferred-node>` immediately. Do not wait for confirmation.
If df-explain returns no match: T2 Inform — `[DevFlow] No node match — searching by file path.` Try file path resolution. If still no match: T3 Gate — ask developer for correct node.

```bash
df-explain <node-name>
```

Read and internalize the full output — especially the DEPENDS ON and DEPENDED ON BY sections.

CHECKPOINT: "[DevFlow] Node identified: <node-id>"

---

## Step 2 — Context Loading

Read in this exact order, **before opening any source files**:

1. The `df-explain` output from Step 1 (already loaded)
2. `.devflow/active/memory.md` — specifically the architecture and conventions sections

Do NOT open any `.cs`, `.svelte`, `.ts`, or other source files yet.

---

## Step 3 — Hypothesis Formation

State a hypothesis explicitly before reading any code.

Print: `[DevFlow] Hypothesis [cycle N/3]: <one-line summary>.` (T2 Inform)
Print: `[DevFlow] Reading <N> files: <file1>, <file2>, ...` (T2 Inform)
Read the files immediately. Do not wait for confirmation.

CHECKPOINT: "[DevFlow] Hypothesis [cycle N/3]: <summary>"

Format the hypothesis output:

```
Hypothesis [cycle 1/3]: <one paragraph description of what you think is wrong and why>

Files to read (from df-explain output):
  - <file 1>  (<reason: inbound/outbound node, or architecture section>)
  - <file 2>  (<reason>)
```

Then read ONLY those files.

---

## Cycle Loop (max 3 cycles)

Each cycle = one hypothesis + targeted file reads + one fix attempt + one test run.

<scope>
EDIT: only files identified in the current hypothesis.
DO NOT: refactor adjacent code, add features, update imports unrelated to the bug, touch untested files.
</scope>

### Apply the fix

Edit only the files identified in the current hypothesis. Do not touch files outside the hypothesis scope unless the fix mechanically requires it (e.g., updating an interface used by the changed file).

### Determine the test command

Check in this order:

1. Does `.devflow/active/slices.json` exist?
2. Does its `feature` field match the current git branch name (`git rev-parse --abbrev-ref HEAD`)?
3. Does at least one slice have `status` ≠ `"done"`?

If all three are true:
- Identify the most relevant slice (the one whose `layers` or `result` description best matches the broken thing)
- Run: `df-test <slice-id>`

Otherwise:
- Read `test_cmd` from `.devflow/config.json`
- Run that command

If no test command is available from either source: tell the developer:
```
[DevFlow] No test command found. Please provide a test command to run.
```
Wait for the developer to provide one before continuing.

### On PASS

Break out of cycle loop. Go to **Success output**.

### On FAIL

1. State what the failure reveals: `"The test failed with <error>. This suggests <revised hypothesis>."`
2. Identify any new files to read if needed
3. Increment cycle counter
4. Start next cycle

### After 3 failed cycles

Do NOT attempt a 4th cycle. Print:

```
[DevFlow] Could not fix after 3 cycles. Here's what I found:

Cycle 1: <hypothesis + what happened>
Cycle 2: <hypothesis + what happened>
Cycle 3: <hypothesis + what happened>

Current state: <describe what was changed, whether changes were reverted>
Suggested next steps: <specific diagnostic hints for the developer>
```

### Cycle Outcome Table

| Outcome | Tests Pass? | Action |
|---------|------------|--------|
| Fix applied | yes | → DONE. State: `CHECKPOINT: "[DevFlow] Fix verified: <description>"` |
| Fix applied | no | → new cycle (max 3 total) |
| Cannot reproduce | — | → T2 Inform: `[DevFlow] Cannot reproduce — describe exact steps`. New hypothesis. |
| 3 cycles exhausted | — | → T3 Gate: show all 3 hypotheses + evidence. Ask for direction. |
| DEFAULT | — | → T2 Inform findings so far. Try new hypothesis. |

---

## Success Output

```
[DevFlow] Fixed in <N> cycle(s).
Hypothesis: <winning hypothesis in one sentence>
Files changed: <list>
Suggested commit: fix: <short description>
```

**REQUIRED:** Before claiming fix is done, follow `skills/verify/SKILL.md`.

---

## Error Reference

| Condition | Behaviour |
|---|---|
| Memory stale (dirty or SHA mismatch) | Auto-run df-sync, print message, continue |
| `graph_conflicts.json` exists | Print conflicted nodes, halt until df-resolve is run |
| `df-explain` returns multiple matches | T3 Gate — list matches, ask which one (genuinely ambiguous) |
| `df-explain` returns no match | T2 Inform — try file path resolution; T3 Gate if still no match |
| No test command available | Ask developer to provide test command |
| `df-test` not on PATH | Fall back to `test_cmd` from `config.json` with warning: `[DevFlow] df-test not found — using config test_cmd` |
| 3 cycles exhausted | Surface findings and diagnosis, do not attempt 4th cycle |

---

## Guard Rails

1. **Hypothesis before code.** State hypothesis (T2 Inform) before reading any source file. — because undirected file reading wastes cycles on wrong files.
2. **Max 3 cycles.** Never start a 4th cycle. T3 Gate — surface findings, ask for direction.
3. **Scope.** Fix only what the hypothesis covers. Don't fix adjacent code.
4. **Reality check.** If it works and hypothesis explains it — done. Don't look for more problems.
5. **Node inference is T2.** Print the inferred node, proceed. Only escalate to T3 if no match found.
6. **File list is T2.** Print files to be read, read them. Do not wait for confirmation.
7. **Exhausted cycles is T3.** After 3 failed cycles: T3 Gate. See `skills/_shared.md`.

---

## Notes

- Never read more files than the hypothesis requires
- Never modify files outside the hypothesis scope without stating why
- Hypothesis must be stated before reading any source file — this is a discipline, not a suggestion
- The fix is not done until the test passes — a hypothesis without a passing test is not a fix

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Fix obvious, skip hypothesis" | Obvious fixes mask root causes. Hypothesize first. |
| "Know which file to change" | Know the file ≠ know the cause. State hypothesis. |
| "3 cycles too many, just ship" | 3 = max, not target. Get it right. |
| "Tests pass, fix works" | Tests passing ≠ root cause fixed. Verify hypothesis. |
| "Memory probably current" | Run staleness check. Probably ≠ verified. |
| "While I'm here, fix this too" | Out of scope. Leave it. |
| "Node is obvious" | T2 Inform it. Don't skip df-explain. |

## Red Flags — STOP

- Opening source files before stating hypothesis
- Skipping df-explain "I know the codebase"
- Fix applied without running test command
- Starting cycle 4
- Fixing adjacent code that wasn't broken

**Stop. State hypothesis. Then read code.**
