## Phase 3: Slice Execution

Goal: implement all slices, batch by batch, with retry loops.

### Batch Execution Loop

For each batch (in order):

1. Read all slices in this batch from their JSON files (check `depends_on` all satisfied)
2. If batch has >1 slice AND slices are parallel-safe AND QUICK_MODE=false: dispatch concurrently using Task tool
3. If QUICK_MODE=true OR batch has 1 slice OR slices are sequential: dispatch one at a time

**For each slice in the batch:**

#### Step 1: Set Up Worktree (parallel slices only)

For parallel batches (full mode), create an isolated worktree per slice:

```bash
df-workspace create feature/<feature-slug>-slice-N
```

Write the worktree path to `slice-N.json` → `worktree_path` field.

For sequential slices (or quick mode): work directly on the feature branch (no worktree).

#### Step 2: Dispatch Implementation Agent

Combine:
- `skills/feature/agents/implementation.md` — role/contract
- `slice-N-<slug>.md` — mission briefing
- Domain Analysis + Pattern Library sections from `plan.md` — context
- If cycle > 1: Prior Work section (see Retry below)

Dispatch as a subagent. Wait for the Implementation Report.

Update `slice-N.json`:
- `status: "in_progress"`
- `cycle: N`

#### Step 3: Handle Implementation Result

**DONE:** Proceed to Step 4. If CONCERNS field is non-empty, log them to `slice-N.json → concerns` and proceed — concerns are non-blocking. The reviewer decides if any are blocking.

**BLOCKED:**
- If context problem → provide context, re-dispatch
- If reasoning problem → re-dispatch with more capable model
- If blocker is a dependency on another slice → add dependency to `depends_on`, defer to next batch
        - If unresolvable → mark `status: "stuck"`, continue with other slices

**After BLOCKED (unresolvable) — mandatory write:**

```
Write to slice JSON: set status = "blocked", blocked_reason = "<reason>"
Append to plan.md: | <slice-name> | BLOCKED | — | — |
CHECKPOINT: "[DevFlow] Slice <name> blocked: <reason>"
```

Update `slice-N.json`:
- `implementation_summary: "..."`
- `files_changed: [...]`
- `concerns: null | "..."`

#### Step 4: Dispatch Test Agent (unless skip criteria met)

**Skip if ALL of:**
- Quick mode AND ≤2 implementation steps AND test_cmd already passed AND no new user-facing behavior

**Always dispatch if any of:**
- New user-facing behavior (any new UI or API)
- >3 files modified
- No existing e2e coverage for this behavior

If skipping: update `slice-N.json` → `test_agent_skipped: true`, `test_agent_skip_reason: "..."`

If dispatching: combine `agents/test.md` + slice mission + domain test patterns. Wait for Test Agent Report.

Update `slice-N.json`:
- `test_summary: {...}`
- `test_result: "PASS (N/N)" | "FAIL (N/N)"`

#### Step 5: Dispatch Slice Review Agent

Combine:
- `agents/slice-review.md` — role/contract
- `slice-N-<slug>.md` — spec to review against
- All files from `files_changed` — actual implementation
- Test results from Step 4 (or test_cmd result if test agent was skipped)
- Domain Analysis from `plan.md` — architecture context

Wait for Slice Review Report.

**If PASS:** mark `slice-N.json` → `status: "done"`. Proceed to next slice.

**After PASS verdict (mandatory write):**

1. Write to slice JSON: set `steps[N].done = true` for all completed steps
2. Append to `plan.md`:

```
| Slice | Status | Verdict | SHA |
|-------|--------|---------|-----|
| <slice-name> | DONE | PASS | <commit-sha> |
```

3. CHECKPOINT: "[DevFlow] Slice <name> complete: PASS"

**If FAIL:** go to Retry.

#### Retry Loop

Max cycles: `slice-N.json` → `max_cycles` (default 3).

On FAIL:
1. Read `review_findings.required_changes` from the Slice Review Report
2. Increment `cycle` in `slice-N.json`
3. If `cycle > max_cycles`: mark `status: "stuck"`, skip this slice, continue

### Issue Fingerprinting (Anti-Cycling)

Track fingerprints across retry cycles: `<file>:<line>:<category>` hash.

| After retry N | Finding delta | Classification | Action |
|--------------|---------------|---------------|--------|
| Any | No issues | CLEAN | → done |
| Retry 2+ | Fewer issues than last | PROGRESS | → continue retrying |
| Retry 2+ | Some resolved, some new | MIXED | → continue, escalate faster |
| Retry 2+ | Same issues persist | STALLED | → mark stuck immediately |
| Retry 2+ | New issues + old persist | REGRESSION | → mark stuck immediately |

On STALLED or REGRESSION: mark slice as stuck immediately. Do not consume remaining retry budget.

Retry dispatch — combine:
- `agents/implementation.md` — role
- `slice-N-<slug>.md` — original mission (DO NOT modify)
- Domain context from `plan.md`
- **Prior Work section** (injected at top of mission context):

```
## Prior Work (Cycle N)

**What was implemented:**
[implementation_summary from previous cycle]

**Files changed:**
- path/to/file.cs — [brief description]

**Test result:** PASS (N/N) | FAIL (N/N)

**Review verdict:** FAIL

**Required changes:**
1. [specific fix]
2. [specific fix]

Read the existing files first. Fix ONLY the listed issues. Do NOT re-implement from scratch.
```

After retry, return to Step 3.

#### Merge Parallel Slices (after each parallel batch)

After all slices in a parallel batch complete (done or stuck):

1. For each slice with a worktree:
   ```bash
   # Merge slice branch into feature branch
   git checkout feature/<feature-slug>
   git merge feature/<feature-slug>-slice-N
   ```
2. If merge conflicts: run `df-resolve` and ask user to resolve, then retry merge
3. Clean up worktrees:
   ```bash
   df-workspace worktree-remove feature/<feature-slug>-slice-N
   ```

#### Stuck Slice Handling

Stuck slices block their dependents but not independent slices.

After a batch completes with stuck slices, report to user:

```
Slice N ("<name>") is stuck after 3 cycles. Its dependents cannot proceed:
- Slice M ("<name>") — blocked

Other slices not dependent on Slice N will continue.
```

Ask: "Would you like to: (1) manually implement slice N and mark it done, (2) remove it and its dependents from scope, or (3) abort?"

---

### Phase 3 Orchestrator Decision Table

| Agent Result | Tests Pass? | Retry Count | Action |
|--------------|------------|-------------|--------|
| DONE | yes | any | → send to reviewer |
| DONE | no | < 3 | → retry with test failures |
| DONE | no | = 3 | → mark stuck, T3 Gate |
| BLOCKED | — | < 3 | → log, retry with more context |
| BLOCKED | — | = 3 | → mark stuck, T3 Gate |
| PASS (reviewer) | — | — | → write state, proceed to next slice |
| FAIL (reviewer) | — | < 3 | → retry implementation with findings |
| FAIL (reviewer) | — | = 3 | → mark stuck, T3 Gate |
| DEFAULT | — | — | → T2 Inform, retry |
