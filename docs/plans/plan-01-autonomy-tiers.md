# Plan 1: Autonomy Tiers

**Status:** Ready  
**Depends on:** Plan 6 (for `_shared.md` location and `.devflow/` structure)  
**Estimated tasks:** 8  
**Execute after:** Plan 6

## Context

DevFlow skills currently have 19+ user gates across 7 skill files. Many ask for confirmation of information the tool already derived correctly (stack detection, node inference, workspace name). This plan creates a canonical tier taxonomy (`skills/_shared.md`) and rewrites each skill's Guard Rails to map every gate to T1/T2/T3.

Net result: init → 1 gate, feature → 3 gates, fix → 1 gate, review/mem-sync/verify → 0 gates.

## Pre-flight

- [ ] `skills/_shared.md` does not yet exist: `[[ ! -f skills/_shared.md ]] && echo OK`
- [ ] Plan 6 is complete (Task 6.6 references tier definitions from `_shared.md`)
- [ ] Record baseline gate counts:
  ```bash
  grep -c "Wait for\|Ask:\|STOPPING GATE\|propose 2-3" skills/init/SKILL.md
  grep -c "STOPPING GATE\|propose 2-3" skills/feature/SKILL.md
  grep -c "propose 2-3\|Wait for" skills/fix/SKILL.md
  grep -c "propose 2-3" skills/review/SKILL.md
  grep -c "propose 2-3" skills/plan/SKILL.md
  grep -c "propose 2-3" skills/mem-sync/SKILL.md
  grep -c "propose 2-3" skills/verify/SKILL.md
  ```

## Tasks

### Task 1.1 — Create skills/_shared.md

**File(s):**
- Create: `skills/_shared.md`

**What:**
Canonical tier definitions file. Loaded by all skills at session start. Must stay under ~200 tokens.

```markdown
# DevFlow Shared Definitions

## Autonomy Tiers

Every DevFlow skill action falls into one of three tiers.

### T1 — Silent
**Do it. No output. No waiting.**
Use when: mechanical, reversible, no judgment required.
Examples: stack detection, workspace name derivation, obvious file classification,
cache checks, git log reads, staleness checks that pass.
Log all T1 actions to session audit list (working memory only, not printed).

### T2 — Inform
**Do it. Print one-line summary. Do not wait.**
Use when: judgment with clear default, reversible, user benefits from knowing.
Format: `[DevFlow] <action taken>: <result>`
Examples: "Memory was stale — synced to abc123", "Targeting auth-service node",
"Reading 4 files: x, y, z, w"

### T3 — Gate
**Present options. Wait for user input. Do not proceed.**
Use when: irreversible, high-stakes, or genuinely ambiguous.
Format: present decision clearly, offer concrete options or Y/N. Always wait.

## Classification Table

| Reversible? | Judgment required? | High-stakes? | Tier |
|-------------|--------------------|--------------|------|
| Yes         | No                 | No           | T1   |
| Yes         | Yes (clear default)| No           | T2   |
| Yes         | Yes (ambiguous)    | No           | T2 — state assumption, proceed |
| No          | Any                | No           | T3   |
| Any         | Any                | Yes          | T3   |

**High-stakes = permanently modifies memory, git history, or user-owned files.**

## Session Audit Log

Every T1 action MUST be logged in working memory as:
`[T1] <step>: <action taken>`

Available on request. Never printed automatically.
```

**Verify:**
```bash
[[ -f skills/_shared.md ]] && echo exists
wc -w skills/_shared.md  # <200 tokens ≈ <150 words
grep -c "T1\|T2\|T3" skills/_shared.md  # ≥ 6 matches
```

---

### Task 1.2 — Rewrite init/SKILL.md Guard Rails

**File(s):**
- Modify: `skills/init/SKILL.md` — Guard Rails, Red Flags, and Steps 2–5

**What:**
This task handles the Guard Rails and step language only. The init skill rewrite in Plan 6 Task 6.6 handles step content. These two tasks modify different sections and can be applied together.

Replace Guard Rails section with:
```markdown
## Guard Rails

1. **One gate only.** The only T3 gate is the final summary. Never add gates before it.
2. **T1 for derivable decisions.** Stack detection, workspace name, file classification are T1 Silent. See `skills/_shared.md`.
3. **T2 for inferences.** Print stack detection result before the gate. Do not ask for pre-confirmation.
4. **Merge, not overwrite.** Re-init merges existing `confidence:"manual"` nodes — never silently deletes them.
5. **Reality check.** Don't reclassify correctly classified nodes.
```

Replace Red Flags section with:
```markdown
## Red Flags — STOP

- Writing memory without the final summary gate
- Overwriting existing `confidence:"manual"` nodes
- Adding any gate before the final summary
- Asking user to confirm stack detection before showing the summary

**One gate. Final. Then write.**
```

**Verify:**
```bash
grep -c "Wait for\|Is this correct\|\[Y\] Yes\|\[A\]\|\[B\]" skills/init/SKILL.md
# Expected: 1 (final summary gate only)
grep "_shared.md" skills/init/SKILL.md
```

---

### Task 1.3 — Rewrite feature/SKILL.md Guard Rails

**File(s):**
- Modify: `skills/feature/SKILL.md` — Guard Rails, Rationalization Prevention, Red Flags sections

**What:**
Keep exactly 3 T3 gates (PRD in phase-0, slices in phase-2, completion in phase-6). All others → T2.

Replace Guard Rails section with:
```markdown
## Guard Rails

These rules are ABSOLUTE:

1. **Three T3 gates. No more.** Only: PRD approval (Phase 0), slice plan approval (Phase 2), completion strategy (Phase 6). All other decisions are T1 or T2. See `skills/_shared.md`.
2. **T2 for mid-execution judgments.** Concerns, merge conflicts (auto-resolved), scope ambiguity → T2 Inform with assumption stated. Do not pause.
3. **T1 for mechanical steps.** Worktree creation, git hooks, config writes → T1 Silent.
4. **Never dispatch two batches simultaneously.**
5. **Never modify slice MD files during execution.** They are the spec.
6. **Always update slice JSON immediately** after each agent completes.
7. **Never skip Phase 6.** Memory sync and cleanup must happen.
8. **Never remove `.devflow/plans/` folders.** They are audit trails.
9. **Scope ambiguity → T2 Inform.** State assumption, proceed. Example: `[DevFlow] Scope ambiguous — assuming X. Proceeding. Correct me if wrong.`
10. **Reality check.** Code that works, follows conventions, passes tests — done. Don't invent problems.
```

Update Rationalization Prevention table:
- Remove: `"I know what user wants" | Propose options. Let them choose.`
- Add: `"Scope ambiguous" | T2 Inform with assumption. Don't ask.`
- Keep: `"User impatient, skip gate"` — the 3 T3 gates are non-negotiable.

Update Red Flags:
- Remove: `"Deciding for user without offering options"`
- Add: `"Adding a gate that isn't one of the 3 canonical T3 gates"`

**Verify:**
```bash
grep -r "STOPPING GATE\|Approval Gate" skills/feature/
# Expected: exactly 3 matches across phase-0-prd.md, phase-2-slices.md, phase-6-completion.md
grep "propose 2-3" skills/feature/SKILL.md  # Expected: 0 matches
grep "_shared.md" skills/feature/SKILL.md
```

---

### Task 1.4 — Rewrite fix/SKILL.md Guard Rails

**File(s):**
- Modify: `skills/fix/SKILL.md` — Steps 1 and 3, Guard Rails, Rationalization Prevention

**What:**
Reduce 3 gates to 1. Changes:

**Step 1 — Node inference:** Change from "Is that right? (Y / different node)" to:
```
### Step 1 — T2: Node inference
Print: `[DevFlow] Targeting [<node>] (<kind>) — <file>.`
Run `df-explain <node>` immediately. Do not wait.
If no match found: T3 Gate — ask developer for the correct node.
```

**Step 3 — Hypothesis file list:** Change from "does this look right? (Y / adjust list)" to:
```
### Step 3 — T2: Hypothesis file list
Print: `[DevFlow] Hypothesis [cycle N/3]: <one-line summary>.`
Print: `[DevFlow] Reading <N> files: <file1>, <file2>, ...`
Read immediately. Do not wait.
```

Replace Guard Rails section with:
```markdown
## Guard Rails

1. **Hypothesis before code.** State hypothesis (T2 Inform) before reading any source file.
2. **Max 3 cycles.** Never start a 4th. Surface findings (T3 Gate).
3. **Scope.** Fix only what the hypothesis covers. Don't touch adjacent code.
4. **Reality check.** If it works and hypothesis explains it — done.
5. **Node inference is T2.** Print, proceed. T3 only if no match found.
6. **File list is T2.** Print, read. Do not ask for confirmation.
7. **Exhausted cycles is T3.** After 3 failed cycles: T3 Gate. See `skills/_shared.md`.
```

**Verify:**
```bash
grep -c "Wait for\|Is that right\|does this look right" skills/fix/SKILL.md
# Expected: 0
grep "T3 Gate\|3 failed cycles" skills/fix/SKILL.md  # ≥1 match
grep "_shared.md" skills/fix/SKILL.md
```

---

### Task 1.5 — Rewrite review/SKILL.md Guard Rails

**File(s):**
- Modify: `skills/review/SKILL.md` — Guard Rails section

**What:**
Remove Guard Rail 8 ("propose 2-3 options for ambiguous convention interpretation") and replace with T2 Inform pattern.

Replace Guard Rails section with:
```markdown
## Guard Rails

1. **Memory before diff.** Always read `memory.md` before examining code changes.
2. **Conventions, not opinions.** Every finding must reference a specific convention or graph relationship.
3. **Read-only.** This skill never modifies files, suggests fixes, or creates commits.
4. **Ambiguous convention → T2.** State the interpretation used: `[DevFlow] Convention ambiguous — interpreting as X per memory.md pattern Y.` Continue analysis. See `skills/_shared.md`.
5. **Contested nodes → flag.** Tag findings on contested-intent nodes with [CONTESTED].
6. **Reality check.** Code that follows all known conventions — no finding needed. Don't invent issues.
```

**Verify:**
```bash
grep "propose 2-3" skills/review/SKILL.md  # Expected: 0
grep "T2\|_shared.md" skills/review/SKILL.md  # ≥1 match each
```

---

### Task 1.6 — Rewrite plan/SKILL.md Guard Rails

**File(s):**
- Modify: `skills/plan/SKILL.md` — Guard Rails section

**What:**
Keep the plan approval gate (T3 — appropriate: plan modifies `.devflow/plans/`). Remove "propose 2-3 options" language from domain analysis.

Replace Guard Rails section with:
```markdown
## Guard Rails

1. **Domain analysis is T1/T2.** Module inference → T1 Silent. Reference pattern loading → T2 Inform.
2. **Plan approval is T3.** The plan modifies `.devflow/plans/`. This is the single gate.
3. **Read-only on `.devflow/active/`.** Plan skill never writes to the active memory. Only plan files are written.
4. **No active plan check.** If `.devflow/plans/` has an in-progress plan: T3 Gate before starting a new one.
5. **Reality check.** Plan tasks should match the actual scope requested. Don't gold-plate. See `skills/_shared.md`.
```

**Verify:**
```bash
grep "propose 2-3" skills/plan/SKILL.md  # Expected: 0
grep "T3\|_shared.md" skills/plan/SKILL.md  # ≥1 each
```

---

### Task 1.7 — Rewrite mem-sync/SKILL.md Guard Rails

**File(s):**
- Modify: `skills/mem-sync/SKILL.md` — Guard Rails section

**What:**
Remove the sync failure gate. Replace with T2 Inform + auto-retry pattern. mem-sync should be fully autonomous.

Replace Guard Rails section with:
```markdown
## Guard Rails

1. **Never silently continue with stale memory.** Always verify before proceeding.
2. **df-sync failure → T2 auto-retry.** On failure: `[DevFlow] df-sync failed (exit <N>) — retrying once.` Retry. If second failure: `[DevFlow] df-sync failed twice — proceeding with stale memory. Risk: memory may not reflect recent changes.` Continue.
3. **No T3 gates.** mem-sync is fully autonomous. See `skills/_shared.md`.
4. **Staleness check is T1.** Run check, log result in working memory. Print only if action taken.
5. **Reality check.** If memory.json exists and last_synced matches HEAD — memory is fresh. Don't re-sync unnecessarily.
```

**Verify:**
```bash
grep "propose 2-3\|Wait for" skills/mem-sync/SKILL.md  # Expected: 0
grep "T2\|auto-retry\|_shared.md" skills/mem-sync/SKILL.md  # ≥1 each
```

---

### Task 1.8 — Rewrite verify/SKILL.md Guard Rails

**File(s):**
- Modify: `skills/verify/SKILL.md` — Guard Rails section

**What:**
Remove the partial failure gate. Verify should run all checks and report results without stopping to ask.

Replace Guard Rails section with:
```markdown
## Guard Rails

1. **No completion claims without evidence.** Run the commands. Read the output. Then claim.
2. **Partial failures → T2 report.** Run all checks. Print: `[DevFlow] Verify: 3/4 passed. Failed: <check-name> (<reason>).` Continue to caller. See `skills/_shared.md`.
3. **No T3 gates.** Verify is fully autonomous — it reports, it does not decide.
4. **Evidence is the output, not the command.** Don't say "tests pass" without reading the actual test output.
5. **Reality check.** All checks pass, output confirms it — done. Don't look for additional problems.
```

**Verify:**
```bash
grep "propose 2-3\|Wait for" skills/verify/SKILL.md  # Expected: 0
grep "T2\|_shared.md" skills/verify/SKILL.md  # ≥1 each
```

---

## Verification Gates

After all tasks complete:

- [ ] `skills/_shared.md` exists and has T1/T2/T3 definitions
- [ ] init/SKILL.md has exactly 1 T3 gate
- [ ] feature/SKILL.md has 0 "propose 2-3" in Guard Rails
- [ ] `grep -r "STOPPING GATE" skills/feature/` returns exactly 3 matches
- [ ] fix/SKILL.md: 0 "Wait for", "Is that right", "does this look right"
- [ ] review/SKILL.md: 0 "propose 2-3"
- [ ] plan/SKILL.md: 0 "propose 2-3"
- [ ] mem-sync/SKILL.md: 0 "propose 2-3", 0 "Wait for"
- [ ] verify/SKILL.md: 0 "propose 2-3", 0 "Wait for"
- [ ] All 7 skills reference `_shared.md`

## Rollback

```bash
git checkout HEAD -- skills/init/SKILL.md skills/feature/SKILL.md \
  skills/fix/SKILL.md skills/review/SKILL.md skills/plan/SKILL.md \
  skills/mem-sync/SKILL.md skills/verify/SKILL.md
rm -f skills/_shared.md
```
