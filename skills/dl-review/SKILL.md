---
name: devline-review
description: Convention-driven code review of diffs against project memory
requires: []
requires_if:
  dl-sync: memory_stale
triggers_on_complete: []
---

# /dl-review — Convention-Driven Code Review

Review diffs against project conventions stored in memory. Every finding cites a specific convention or graph evidence — no opinions.

**Invoked as:** `/dl-review [--base <branch>] [--headless]`

<iron-law>
Load `skills/_shared.md` before proceeding. T1/T2/T3 tiers assumed throughout.
Run checks in severity order: BLOCKING first. Do not proceed to lower-severity checks until all BLOCKING issues are resolved. — because continuing to review code with type errors wastes effort and obscures other findings.
</iron-law>

---

## Gates: 0 (fully autonomous)

---

## Pre-flight (T1 Silent)

1. Check `.devline/` exists — if not: run in degraded mode (skip convention checks). — because review of a non-Devline project is still useful with reduced rigor; full halt would block ad-hoc reviews.
2. **Memory freshness:** Apply the Pre-Flight Staleness Check defined in `skills/_shared.md`.
3. Confirm base branch: `git merge-base HEAD main` — default is `main` unless config specifies otherwise

---

## Phase 1 — Context Loading (T1 Silent)

1. Read `.devline/memory.md` (architecture + conventions)
2. Read `.devline/decisions.md` if present — index by file/module path. Findings about a file/module that match a prior `Override:` entry MUST NOT be re-flagged unless the diff materially changes the context. — because re-flagging settled questions burns user trust faster than missing a real issue.
3. Read full diff: `git diff <base>...HEAD`
   - If >30 files: read top 30 by node connectivity (run `dl-explain --rank --budget 30` and cross-reference with changed files)
4. For each changed file: `dl-explain --node <file>` → collect symbol names + inbound/outbound edges
5. Run `dl-explain --impact` → detect_changes blast radius for current diff

CHECKPOINT: "[Devline] dl-review Phase 1 done: context loaded"

---

## Phase 1.5 — PRD Acceptance Criteria Verification (FIRST)

Before checking code conventions, verify the feature actually does what was agreed.

For each acceptance criterion in the PRD (from `plan.md`):

| Criterion | Met? | Evidence |
|-----------|------|----------|
| [criterion 1] | yes/no | [test name / observable behavior] |
| [criterion 2] | yes/no | [test name / observable behavior] |

If any criterion is unmet: mark review **BLOCKING**. Do not proceed to convention checks.

CHECKPOINT: "[Devline] dl-review Phase 1.5 done: PRD criteria checked"

---

## Phase 2 — Convention Analysis (Parallel per-check Tasks)

Each check below runs as its **own subagent Task**, dispatched in parallel from a single message (one `Task` call per active check). The orchestrator collects all reports, then synthesizes the verdict in Phase 3. — because monolithic review lets later checks crowd earlier findings out of context and serialises work that has no real ordering dependency; per-check Tasks give each rule its own bounded context window and let four checks finish in the wall-clock time of one.

**Dispatch contract per check Task:**

| Slot | Source |
|------|--------|
| `subagent_type` | `general-purpose` |
| `description` | `dl-review: <check-name>` (≤7 words) |
| `prompt` | Combine: (a) the single check's row from the table below, (b) full diff `git diff <base>...HEAD` (or top-30 subset from Phase 1), (c) the relevant excerpt of `memory.md` for that convention, (d) any matching `decisions.md` overrides for the changed files. |
| `output contract` | Return ONLY a JSON array: `[{severity, file, line, convention, finding}]` (empty array if no findings). No prose. |

**Parallelism rule:** Dispatch ALL active checks (default checks + each user-defined check from `config.json.review_checks`) in a single assistant message with multiple `Task` blocks. Wait for all to return. Do NOT dispatch sequentially — that defeats the purpose.

**Severity ordering applies to the synthesis in Phase 3, not the dispatch:** all checks run regardless of whether earlier ones found BLOCKING issues, because each Task has independent context — there is no wasted work and the user gets the full picture in one pass.

**Only flag if the relevant convention exists in memory.md or graph evidence is conclusive.** Never flag based on opinion.

### Severity Reference

| Finding type | Severity | Action |
|-------------|----------|--------|
| PRD criterion unmet | BLOCKING | FAIL — report which criterion |
| Security vulnerability | BLOCKING | FAIL — describe the risk and affected code |
| Type error / compile failure | BLOCKING | FAIL — name the error and file |
| Architecture violation | BLOCKING | FAIL — describe the violation and convention |
| Missing test coverage for new behavior | WARNING | FAIL — name the uncovered path |
| Dead code introduced | WARNING | Report — name the symbol |
| Near-clone detected | NOTE | Report — name the similar symbol |
| Naming inconsistency | NOTE | Report with correct form |
| DEFAULT | NOTE | Report if evidence is conclusive |

### Default Checks (from config `review_checks`)

| # | Check | Trigger | Severity |
|---|-------|---------|----------|
| 1 | **Naming deviations** | Changed symbol name doesn't match naming pattern in memory.md | WARNING |
| 2 | **Missing test coverage** | Changed source file has no corresponding test change in diff | WARNING |
| 3 | **Unclassified files** | New files not recognized by any classifier in config.json | NOTE |
| 4 | **Impact radius** | Inbound callers of changed symbols not in diff | NOTE |
| 5 | **Dead code introduced** | `dl-explain --dead-code` returns new zero-caller functions from diff | WARNING |
| 6 | **Near-clone detection** | `dl-explain --clones` returns SIMILAR_TO edges with score > 0.8 in changed files | NOTE |

### User-Defined Checks

Read `review_checks` array from `.devline/config.json`. Each object entry with `name`, `severity`, `convention` fields is applied as an additional check. Only flag if diff matches the pattern described in `convention`.

Example config entry:
```json
{ "name": "service-communication", "severity": "BLOCKING", "convention": "Services communicate only via events, never direct calls" }
```

### Degraded Mode (no .devline/)

If `.devline/` missing (CI without init):
- Skip convention checks
- Provide general observations only (file-level, no graph context)
- T2 Inform: "Running in degraded mode — no Devline memory. Convention checks skipped."

---

## Phase 3 — Synthesis & Output

Collect the JSON arrays returned by each parallel check Task. Merge into one list, then:

1. **De-dup** by `(file, line, convention)` — multiple checks may flag the same line.
2. **Filter against decisions.md** — drop any finding whose `(file, convention)` matches a prior `Override:` entry, unless the diff in this file has materially changed the conditions of the override. Log dropped overrides at T1 Silent.
3. **Group by severity:** BLOCKING → WARNING → NOTE

Each finding format:
```
[SEVERITY] Finding description
Convention: "{exact convention from memory.md or Cypher query result}"
Location: file:line
```

Impact radius section:
```
Inbound nodes affected but NOT in diff: {list}
Consider: do callers need updating?
```

Verdict: **PASS** | **CONCERNS** | **BLOCKING**

CHECKPOINT: "[Devline] dl-review Phase 3 done: verdict = [PASS/CONCERNS/BLOCKING]"

---

## Headless Mode (CI/CD)

Run: `devline review --headless`

In headless mode:
- T3 gates auto-approve (review always runs to completion)
- Output written to `devline-headless.log`
- Exit codes: 0=PASS, 1=BLOCKING findings, 2=CONCERNS

Typical CI usage:
```yaml
- run: devline review --headless
  # Fails build on BLOCKING findings (exit 1)
  # Advisory on CONCERNS (exit 2 = warning only)
```

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Finding is obvious, skip citation" | Every finding cites a convention. Always. |
| "This is my opinion but it's right" | Not a convention = not a finding. |
| "Too many findings, cut it short" | Report all. Let user prioritize. |
| "Tests pass so review can be lenient" | Tests = behavior. Review = architecture. Both. |

## Red Flags — STOP

- Skipping convention checks because "code looks fine"
- Approving without reading memory.md conventions
- "Minor issues, not worth mentioning" — mention everything
- Running review on uncommitted changes (commit first)
- Reviewing your own code without fresh context

**Stop. Load conventions. Check everything.**
