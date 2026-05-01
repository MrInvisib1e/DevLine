# Spec B: Discipline Enforcement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden all DevFlow skills against rationalization under pressure — add iron laws, terse rationalization tables, red flag lists, a standalone verification skill, a universal reality check, and a universal decision protocol.

**Architecture:** 5 items. B2 (`/verify` skill) must be done first since B1 adds cross-references to it. B1, B3, B4, B5 are all additive edits to existing skills — no behavioral changes. Order: B2 → B1 → B4 → B5 → B3. B3 includes `/plan` and `/verify` content baked in from scratch (no separate step needed for those two files).

**Tech Stack:** Markdown only. No shell scripts modified.

---

## Style Rules for All Additions

**Terse over polished.** Short phrases in tables. Skip grammar where correctness is preserved.

Rationalization table format:
```markdown
| Excuse | Reality |
|--------|---------|
| "Short excuse phrase" | Short correction. |
```

Red flags format — short phrases, not sentences:
```markdown
## Red Flags — STOP

- Short phrase
- "Quote from rationalization"
```

---

## File Change Map

| File | Items | Change |
|------|-------|--------|
| `skills/verify/SKILL.md` | B2 | New — standalone verification skill |
| `skills/feature/SKILL.md` | B1, B4, B5 | Add iron law + tables + red flags + reality check + decision protocol |
| `skills/review/SKILL.md` | B1, B4, B5 | Add iron law + tables + red flags + reality check + decision protocol |
| `skills/fix/SKILL.md` | B3, B4, B5 | Add iron law + tables + red flags + reality check + decision protocol |
| `skills/init/SKILL.md` | B3, B4, B5 | Add iron law + tables + red flags + reality check + decision protocol |
| `skills/mem-sync/SKILL.md` | B3, B4, B5 | Add iron law + tables + red flags + reality check + decision protocol |
| `skills/plan/SKILL.md` | B3 baked in | Created in Spec A with all discipline content already included |
| `skills/verify/SKILL.md` | B2 baked in | Created in this plan with all discipline content already included |

---

## Task 1: Create `/verify` Skill (B2)

**Must be done before Task 2** — other skills will reference `skills/verify/SKILL.md`.

**Files:**
- Create: `skills/verify/SKILL.md`

- [ ] **Step 1: Create `skills/verify/` directory**

```bash
mkdir -p skills/verify
```

- [ ] **Step 2: Create `skills/verify/SKILL.md`**

```markdown
---
name: devflow-verify
description: Use when about to claim a slice is done, a fix is applied, a review is complete, or any DevFlow task is finished — requires running verification commands before making success claims
---

# Skill: verify

# DevFlow Verify

Run verification before claiming any DevFlow task is done. Evidence before claims. Always.

**Invoked as:** Referenced by other skills before completion claims. Also safe to call directly.

---

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

---

## Gate Function

What to run before claiming done:

| Claiming... | Must run | Must confirm |
|-------------|----------|-------------|
| Slice done | `df-test <slice-id>` or `test_cmd` from config | Exit 0, all tests pass |
| Fix applied | Test that reproduces the original bug | Bug no longer reproduces |
| Review complete | Re-read full diff after any late changes | Findings still accurate |
| Memory synced | `df-sync` + check `dirty=false` | `last_synced` = HEAD |
| Feature complete | Full test suite via `test_cmd` | Exit 0 |
| Slice JSON updated | Read JSON file back | Fields match claim |

---

## Guard Rails

1. **Evidence before claims.** Run the command. Read the output. Then state the result.
2. **Fresh verification.** Earlier passing ≠ passing now. Run again.
3. **Reality check.** If it passed and nothing changed — it's still passing. No need to re-run unnecessarily.
4. **Decision protocol.** Partial failures → propose options (fix now, defer, or proceed with known failures documented).

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier" | Earlier ≠ now. Run again. |
| "Just wrote the fix, it works" | Confidence ≠ evidence. Run test. |
| "df-test is slow" | Slow verification > fast false claim. |
| "JSON is just bookkeeping" | Stale JSON breaks resume. Update it. |
| "Review found nothing, skip re-check" | Re-read diff. Confirm. |
| "I know what user wants done" | Propose options. Let them choose. |
| "Nothing changed, no need to verify" | If nothing changed — skip is fine. Otherwise run it. |

## Red Flags — STOP

- "Should work", "probably passes", "looks correct"
- Marking slice done without running df-test
- Claiming fix without reproducing original failure
- "Great!", "Done!" before verification
- Trusting agent reports without independent check

**Run the command. Read the output. Then claim the result.**

---

## When to Apply

- Before marking slice `status: "done"`
- Before claiming `/fix` resolved the bug
- Before reporting `/review` verdict
- Before Phase 6 completion
- Before any commit implying success
```

- [ ] **Step 3: Verify file created**

```bash
head -4 skills/verify/SKILL.md
```

Expected: starts with `---`, `name: devflow-verify`

- [ ] **Step 4: Commit**

```bash
git add skills/verify/SKILL.md
git commit -m "feat: add standalone /verify skill for DevFlow completion verification"
```

---

## Task 2: Discipline Additions to `/feature` (B1 + B4 + B5)

**Files:**
- Modify: `skills/feature/SKILL.md`

All additions are new sections appended or inserted at specific locations. No existing content is modified.

- [ ] **Step 1: Add iron law after Quick Reference table**

Insert this block after the `## Quick Reference` table and before `## Pre-Flight`:

```markdown
## The Iron Law

```
NO CODE WITHOUT APPROVED SLICES. NO MERGE WITHOUT PASSING REVIEW.
```

Haven't passed a stopping gate → cannot proceed. Period.

---
```

- [ ] **Step 2: Add verify reference to Phase Dispatch section**

In the `## Phase Dispatch` table, add a note after the table:

```markdown
**REQUIRED:** Before marking any slice done or claiming feature complete, follow `skills/verify/SKILL.md`.
```

- [ ] **Step 3: Add guard rails additions (reality check + decision protocol)**

In the `## Guard Rails` section, add after the existing 7 rules:

```markdown
8. **Reality check.** Code that works, follows conventions, and passes tests — done. Don't invent problems. Don't refactor what isn't broken.
9. **Decision protocol.** When input is needed, propose 2-3 concrete options with trade-offs. Never decide for the user. Never ask open-ended "what do you want?" — give choices.
```

- [ ] **Step 4: Add rationalization table + red flags after Guard Rails**

Add this block after the Guard Rails section:

```markdown
## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "User impatient, skip gate" | Skip gate → rework. Run it. |
| "PRD obvious, no need to ask" | Obvious PRDs have hidden assumptions. Ask. |
| "Just one slice, skip integration" | Single slices still need Phase 5 review. |
| "Minor issues, ship anyway" | Minor issues compound. Fix them. |
| "Tests pass, skip review agent" | Tests = behavior. Review = architecture. Both. |
| "Fix it next feature" | Next feature won't fix this one. |
| "Quick mode = less rigor" | Fewer questions. Not fewer checks. |
| "While I'm here, fix this too" | Out of scope. Works. Leave it. |
| "I know what user wants" | Propose options. Let them choose. |

## Red Flags — STOP

- Code before slice approval
- "Gate doesn't apply here"
- Skipping a phase because "obvious"
- Next batch dispatched before current batch review done
- Modifying slice MD during execution
- About to merge without Phase 5
- "Quick mode means skip this"
- Fixing adjacent code that wasn't broken
- Deciding for user without offering options

**Stop. Re-read guard rails. Follow the process.**
```

- [ ] **Step 5: Verify file still valid (no broken markdown)**

```bash
wc -l skills/feature/SKILL.md
```

Expected: coordinator should now be ~210 lines (original ~150 + ~60 lines of new discipline content)

- [ ] **Step 6: Commit**

```bash
git add skills/feature/SKILL.md
git commit -m "feat: add iron law, rationalization table, red flags to feature skill"
```

---

## Task 3: Discipline Additions to `/review` (B1 + B4 + B5)

**Files:**
- Modify: `skills/review/SKILL.md`

- [ ] **Step 1: Add iron law after Quick Reference table**

Insert after `## Quick Reference` table and before `## Pre-Flight`:

```markdown
## The Iron Law

```
CONVENTIONS, NOT OPINIONS. MEMORY BEFORE DIFF. ALWAYS.
```

Convention not in memory.md → not a finding. Haven't read memory.md → can't review.

---
```

- [ ] **Step 2: Add verify reference before Output section**

Before the `## Output` section, add:

```markdown
**REQUIRED:** Before reporting verdict, follow `skills/verify/SKILL.md`.
```

- [ ] **Step 3: Add guard rails additions (reality check + decision protocol)**

Find the existing guard rails section. Add after the last existing rule:

```markdown
- **Reality check.** Convention-compliant code that passes tests — PASS. Don't flag what isn't a convention violation.
- **Decision protocol.** Ambiguous convention interpretation → propose 2-3 options for user to decide. Never resolve ambiguity unilaterally.
```

- [ ] **Step 4: Add rationalization table + red flags after guard rails**

```markdown
## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Code ugly, flag it" | Convention-compliant = PASS. Ugly irrelevant. |
| "I know best practices" | Project conventions override generic practices. |
| "Memory probably fine, skip check" | Stale memory = wrong conventions = wrong findings. |
| "Too many files, skip df-explain" | df-explain = impact radius. Skip = blind review. |
| "No convention here, flag anyway" | No convention = no finding. Note it, don't flag. |
| "Conflicted node, pick one" | Tag contested-intent. Don't resolve during review. |
| "While I'm here, flag style issue" | Not a convention violation. Leave it. |
| "I know what user wants fixed" | Propose options. Let them choose. |

## Red Flags — STOP

- Flagging something not backed by convention in memory.md
- Skipping df-explain on a changed file
- Reading diff before reading memory.md
- Applying generic best practices instead of project conventions
- Resolving contested-intent instead of tagging it
- Claiming PASS without checking impact radius
- Flagging code that works and follows conventions

**Stop. Re-read guard rails. Follow the process.**
```

- [ ] **Step 5: Commit**

```bash
git add skills/review/SKILL.md
git commit -m "feat: add iron law, rationalization table, red flags to review skill"
```

---

## Task 4: Discipline Additions to `/fix` (B3 + B4 + B5)

**Files:**
- Modify: `skills/fix/SKILL.md`

- [ ] **Step 1: Add iron law after trigger examples**

Insert after the trigger examples block and before `## Pre-flight Checks`:

```markdown
## The Iron Law

```
HYPOTHESIS BEFORE CODE. ALWAYS.
```

---
```

- [ ] **Step 2: Add verify reference to success output section**

Find the section describing what to output on success. Add:

```markdown
**REQUIRED:** Before claiming fix is done, follow `skills/verify/SKILL.md`.
```

- [ ] **Step 3: Add guard rails additions**

Find or create a Guard Rails / Notes section at the end. Add:

```markdown
## Guard Rails

1. **Hypothesis before code.** State hypothesis before reading any source file.
2. **Max 3 cycles.** Never start a 4th cycle. Surface findings to user.
3. **Scope.** Fix only what the hypothesis covers. Don't fix adjacent code.
4. **Reality check.** If it works and hypothesis explains it — done. Don't look for more problems.
5. **Decision protocol.** Multiple node matches, exhausted cycles → propose 2-3 options. Let user choose.
```

- [ ] **Step 4: Add rationalization table + red flags**

```markdown
## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Fix obvious, skip hypothesis" | Obvious fixes mask root causes. Hypothesize first. |
| "Know which file to change" | Know the file ≠ know the cause. State hypothesis. |
| "3 cycles too many, just ship" | 3 = max, not target. Get it right. |
| "Tests pass, fix works" | Tests passing ≠ root cause fixed. Verify hypothesis. |
| "Memory probably current" | Run staleness check. Probably ≠ verified. |
| "While I'm here, fix this too" | Out of scope. Leave it. |
| "I know what user wants fixed" | Propose options. Let them choose. |

## Red Flags — STOP

- Opening source files before stating hypothesis
- Skipping df-explain "I know the codebase"
- Fix applied without running test command
- Starting cycle 4
- Fixing adjacent code that wasn't broken

**Stop. State hypothesis. Then read code.**
```

- [ ] **Step 5: Commit**

```bash
git add skills/fix/SKILL.md
git commit -m "feat: add iron law, rationalization table, red flags to fix skill"
```

---

## Task 5: Discipline Additions to `/init` (B3 + B4 + B5)

**Files:**
- Modify: `skills/init/SKILL.md`

- [ ] **Step 1: Add iron law after invocation line**

Insert after the `**When invoked:**` line and before `## Flow`:

```markdown
## The Iron Law

```
NEVER OVERWRITE EXISTING MEMORY WITHOUT EXPLICIT USER CONSENT.
```

---
```

- [ ] **Step 2: Add guard rails section**

Add before or after the existing error reference:

```markdown
## Guard Rails

1. **Consent before write.** Never write memory without user confirming stack detection.
2. **Merge, not overwrite.** Re-init merges with existing nodes — never silently deletes them.
3. **Surface unclassified files.** Never skip the unclassified file batch — they are blind spots.
4. **Reality check.** If a node is correctly classified and working — leave it. Don't reclassify for the sake of it.
5. **Decision protocol.** Stack override, custom types, ambiguous files → propose 2-3 options. Let user choose.
```

- [ ] **Step 3: Add rationalization table + red flags**

```markdown
## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Re-init fixes stale data" | Re-init merges, not overwrites. Confirm with user. |
| "AI classification good enough" | Always confirm stack detection with developer. |
| "Skip unclassified, unimportant" | Unclassified = blind spots. Surface them. |
| "I know what user wants configured" | Propose options. Let them choose. |
| "Node looks fine, just update it" | Works correctly → leave it. |

## Red Flags — STOP

- Writing memory without user confirmation of stack detection
- Overwriting existing node classifications without consent
- Skipping unclassified file batch
- Deciding custom node types without offering options
- Reclassifying nodes that are already correct

**Stop. Confirm. Then write.**
```

- [ ] **Step 4: Commit**

```bash
git add skills/init/SKILL.md
git commit -m "feat: add iron law, rationalization table, red flags to init skill"
```

---

## Task 6: Discipline Additions to `/mem-sync` (B3 + B4 + B5)

**Files:**
- Modify: `skills/mem-sync/SKILL.md`

- [ ] **Step 1: Add iron law after description line**

Insert after the `**When to invoke:**` line and before `## Prerequisites`:

```markdown
## The Iron Law

```
NEVER SILENTLY CONTINUE WITH STALE MEMORY.
```

---
```

- [ ] **Step 2: Add guard rails section**

Add at end:

```markdown
## Guard Rails

1. **Staleness check first.** Check `last_synced` vs HEAD before reading any memory file.
2. **Run df-sync when stale.** Don't proceed with stale memory.
3. **Verify after sync.** Confirm `dirty: false` and `last_synced` = HEAD after df-sync.
4. **Reality check.** Memory is current (`last_synced` = HEAD, `dirty: false`) → no action needed. Don't sync unnecessarily.
5. **Decision protocol.** df-sync fails → propose 2-3 options (retry, proceed degraded, halt).
```

- [ ] **Step 3: Add rationalization table + red flags**

```markdown
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
- Proceeding when df-sync fails without offering options

**Stop. Check staleness. Then read.**
```

- [ ] **Step 4: Commit**

```bash
git add skills/mem-sync/SKILL.md
git commit -m "feat: add iron law, rationalization table, red flags to mem-sync skill"
```

---

## Final Verification

- [ ] **Verify all skills have iron law**

```bash
grep -rl "The Iron Law" skills/
```

Expected: 6 files (feature, review, fix, init, mem-sync, verify)

- [ ] **Verify all skills have rationalization tables**

```bash
grep -rl "Rationalization Prevention" skills/
```

Expected: 6 files (feature, review, fix, init, mem-sync, verify)

- [ ] **Verify all skills have red flags**

```bash
grep -rl "Red Flags" skills/
```

Expected: 7 files (feature, review, fix, init, mem-sync, verify, plan)

- [ ] **Verify verify skill has gate function table**

```bash
grep -l "Gate Function" skills/verify/SKILL.md
```

Expected: 1 match

- [ ] **Verify cross-references in feature and review**

```bash
grep -r "skills/verify/SKILL.md" skills/feature/SKILL.md skills/review/SKILL.md
```

Expected: 2 matches (one in each file)
