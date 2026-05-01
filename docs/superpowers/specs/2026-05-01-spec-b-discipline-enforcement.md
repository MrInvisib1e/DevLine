# Spec B: Discipline Enforcement

**Date:** 2026-05-01  
**Status:** Approved  
**Scope:** Rationalization tables, iron laws, red flags, verification skill, reality check, decision protocol

---

## Goal

Harden all DevFlow skills against rationalization under pressure. Add iron law framing, terse rationalization tables, red flag lists, a standalone verification skill, a universal reality check principle, and a universal decision protocol to all skills.

---

## Items

| # | Item | Priority | Effort | Depends On |
|---|------|----------|--------|-----------|
| B1 | Rationalization tables + red flags in `/feature` and `/review` | P0 | Low | — |
| B2 | Standalone DevFlow verification skill (`/verify`) | P0 | Low | — |
| B3 | Iron law framing in remaining skills (`/fix`, `/init`, `/mem-sync`, `/plan`) | P2 | Low | Spec A: A3 (for `/plan`) |
| B4 | Universal reality check principle (all skills) | P0 | Low | — |
| B5 | Universal decision protocol (all skills) | P0 | Low | — |

**Implementation order:** B2 before B1 cross-references are added (cross-reference lines point to `skills/verify/SKILL.md` — that file must exist first).

---

## Style Rules for All Additions

**Terse over polished.** Correctness over grammar. Short explanations only. Skip fine grammar where correctness is preserved.

**Rationalization table style:**

```markdown
| Excuse | Reality |
|--------|---------|
| "User impatient, skip gate" | Skip gate → rework. Run it. |
| "Code ugly, flag it" | Convention-compliant = PASS. Ugly irrelevant. |
```

**Red flags style:**

```markdown
## Red Flags — STOP

- Code before slice approval
- "Gate doesn't apply here"
- Modifying slice MD during execution
```

Short phrases, not full sentences. Visual stop signs.

---

## B4: Universal Reality Check (all skills)

Add to every skill's guard rails section:

```markdown
**Reality check:** Not everything needs fixing. Code that works, follows conventions, and passes tests — done. Don't invent problems. Don't refactor what isn't broken. Don't flag what isn't violated.
```

Add to rationalization tables in every skill:

| Excuse | Reality |
|--------|---------|
| "While I'm here, fix this too" | Out of scope. Works. Leave it. |
| "This could be better" | Could ≠ should. Ship what works. |

---

## B5: Universal Decision Protocol (all skills)

Add to every skill's guard rails section:

```markdown
**Decision protocol:** When a decision requires user input — propose 2-3 concrete options with trade-offs. Never decide for the user. Never ask open-ended "what do you want?" — give choices.
```

Add to rationalization tables in every skill:

| Excuse | Reality |
|--------|---------|
| "I know what user wants" | Propose options. Let them choose. |
| "Only one reasonable choice" | Present it. User may disagree. |

**Decision points by skill:**

| Skill | Decision points |
|-------|----------------|
| `/feature` | Stack detection override, slice plan changes, stuck slice handling, quick→full mode switch |
| `/fix` | Multiple node matches, hypothesis confirmation, exhausted cycles |
| `/review` | Ambiguous convention interpretation, degraded mode behavior |
| `/init` | Stack override, custom node types, unclassified file batches |
| `/plan` | Reference feature selection, task ordering alternatives |
| `/verify` | Partial test failures — fix vs proceed |

---

## B1: `/feature` and `/review` Additions

### `/feature` — Iron Law

Add after Quick Reference table, before Pre-Flight:

```markdown
## The Iron Law

```
NO CODE WITHOUT APPROVED SLICES. NO MERGE WITHOUT PASSING REVIEW.
```

Haven't passed a stopping gate → cannot proceed. Period.
```

### `/feature` — Rationalization Table

Add after Guard Rails:

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
```

### `/feature` — Red Flags

Add after rationalization table:

```markdown
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

---

### `/review` — Iron Law

Add after Quick Reference table:

```markdown
## The Iron Law

```
CONVENTIONS, NOT OPINIONS. MEMORY BEFORE DIFF. ALWAYS.
```

Convention not in memory.md → not a finding. Haven't read memory.md → can't review.
```

### `/review` — Rationalization Table

Add after Guard Rails:

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
| "While I'm here, flag this style issue" | Not a convention violation. Leave it. |
| "I know what user wants fixed" | Propose options. Let them choose. |
```

### `/review` — Red Flags

Add after rationalization table:

```markdown
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

---

## B2: Standalone Verification Skill

### File

`skills/verify/SKILL.md` (~120 lines)

### Frontmatter

```yaml
---
name: devflow-verify
description: Use when about to claim a slice is done, a fix is applied, a review is complete, or any DevFlow task is finished — requires running verification commands before making success claims
---
```

### Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

### Gate Function

What to run before claiming done:

| Claiming... | Must run | Must confirm |
|-------------|----------|-------------|
| Slice done | `df-test <slice-id>` or `test_cmd` from config | Exit 0, all tests pass |
| Fix applied | Test that reproduces the original bug | Bug no longer reproduces |
| Review complete | Re-read full diff after any late changes | Findings still accurate |
| Memory synced | `df-sync` + check `dirty=false` | `last_synced` = HEAD |
| Feature complete | Full test suite via `test_cmd` | Exit 0 |
| Slice JSON updated | Read JSON file back | Fields match claim |

### Rationalization Table

```markdown
| Excuse | Reality |
|--------|---------|
| "Tests passed earlier" | Earlier ≠ now. Run again. |
| "Just wrote the fix, it works" | Confidence ≠ evidence. Run test. |
| "df-test is slow" | Slow verification > fast false claim. |
| "JSON is just bookkeeping" | Stale JSON breaks resume. Update it. |
| "Review found nothing, skip re-check" | Re-read diff. Confirm. |
| "I know what user wants done" | Propose options. Let them choose. |
```

### Red Flags

```markdown
## Red Flags — STOP

- "Should work", "probably passes", "looks correct"
- Marking slice done without running df-test
- Claiming fix without reproducing original failure
- "Great!", "Done!" before verification
- Trusting agent reports without independent check

**Run the command. Read the output. Then claim the result.**
```

### When to Apply

- Before marking slice `status: "done"`
- Before claiming `/fix` resolved the bug
- Before reporting `/review` verdict
- Before Phase 6 completion
- Before any commit implying success

### Cross-References Added to Other Skills

One-line reference added to:

- `/feature` Phase 3 Step 5 (after slice review passes): `**REQUIRED:** Before marking this slice done, follow \`skills/verify/SKILL.md\`.`
- `/feature` Phase 6 Step 1 (before memory sync): `**REQUIRED:** Before claiming feature complete, follow \`skills/verify/SKILL.md\`.`
- `/fix` success output section: `**REQUIRED:** Before claiming fix is done, follow \`skills/verify/SKILL.md\`.`
- `/review` output section (before verdict): `**REQUIRED:** Before reporting verdict, follow \`skills/verify/SKILL.md\`.`

---

## B3: Iron Law Framing in Remaining Skills

### `/fix` — Iron Law

Add after trigger examples:

```markdown
## The Iron Law

```
HYPOTHESIS BEFORE CODE. ALWAYS.
```
```

### `/fix` — Rationalization Table

Add at end, before Notes:

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
```

### `/fix` — Red Flags

```markdown
## Red Flags — STOP

- Opening source files before stating hypothesis
- Skipping df-explain "I know the codebase"
- Fix applied without running test command
- Starting cycle 4
- Fixing adjacent code that wasn't broken

**Stop. State hypothesis. Then read code.**
```

---

### `/init` — Iron Law

Add after invocation line:

```markdown
## The Iron Law

```
NEVER OVERWRITE EXISTING MEMORY WITHOUT EXPLICIT USER CONSENT.
```
```

### `/init` — Rationalization Table

```markdown
## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Re-init fixes stale data" | Re-init merges, not overwrites. Confirm with user. |
| "AI classification good enough" | Always confirm stack detection with developer. |
| "Skip unclassified files, unimportant" | Unclassified = blind spots. Surface them. |
| "I know what user wants configured" | Propose options. Let them choose. |
| "This looks right, no need to change" | If works and correct — leave it. |
```

### `/init` — Red Flags

```markdown
## Red Flags — STOP

- Writing memory without user confirmation of stack detection
- Overwriting existing node classifications without consent
- Skipping unclassified file batch
- Deciding custom node types without offering options

**Stop. Confirm. Then write.**
```

---

### `/mem-sync` — Iron Law

Add after invocation description:

```markdown
## The Iron Law

```
NEVER SILENTLY CONTINUE WITH STALE MEMORY.
```
```

### `/mem-sync` — Rationalization Table

```markdown
## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Memory probably fine" | Check last_synced vs HEAD. Probably ≠ verified. |
| "df-sync slow, skip it" | Stale memory = wrong context = wrong decisions. |
| "Sync after" | After is too late. Sync before reading. |
| "Memory fresh enough" | Fresh enough ≠ current. Check. |
```

### `/mem-sync` — Red Flags

```markdown
## Red Flags — STOP

- Proceeding to read memory.md without staleness check
- Skipping df-sync when dirty=true
- Skipping df-sync when last_synced ≠ HEAD

**Stop. Check staleness. Then read.**
```

---

### `/plan` (new from Spec A) — Iron Law

Add after invocation description:

```markdown
## The Iron Law

```
MEMORY BEFORE PLANNING. NO PLAN WITHOUT df-explain.
```
```

### `/plan` — Rationalization Table

```markdown
## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Know the codebase, skip df-explain" | Graph shows impact radius you don't know. Run it. |
| "Memory probably current" | Check staleness. Probably ≠ verified. |
| "Plan obvious, skip approval" | Present plan. User decides. |
| "While I'm here, plan this refactor too" | Out of scope. Stick to the task. |
| "I know what user wants planned" | Propose options. Let them choose. |
```

### `/plan` — Red Flags

```markdown
## Red Flags — STOP

- Planning without reading memory.md
- Skipping df-explain on relevant nodes
- Presenting plan without waiting for approval
- Expanding scope beyond the described task

**Stop. Load memory. Run df-explain. Then plan.**
```

---

## Non-Goals

- No changes to shell scripts (`bin/`)
- No changes to agents templates
- No changes to bats tests
- No new stopping gates beyond what's already designed
- No new phases or skills beyond `/verify`

---

## File Change Summary

| File | Change |
|------|--------|
| `skills/feature/SKILL.md` | Iron law + rationalization table + red flags + B4 + B5 additions |
| `skills/review/SKILL.md` | Iron law + rationalization table + red flags + B4 + B5 additions |
| `skills/fix/SKILL.md` | Iron law + rationalization table + red flags + B4 + B5 additions |
| `skills/init/SKILL.md` | Iron law + rationalization table + red flags + B4 + B5 additions |
| `skills/mem-sync/SKILL.md` | Iron law + rationalization table + red flags + B4 + B5 additions |
| `skills/plan/SKILL.md` | Iron law + rationalization table + red flags + B4 + B5 (written fresh as part of A3) |
| `skills/verify/SKILL.md` | New — standalone verification skill |

**Note:** `/plan` and `/verify` are new files. All discipline content is baked in from the start — no separate "add B3/B4/B5" step needed for them.
