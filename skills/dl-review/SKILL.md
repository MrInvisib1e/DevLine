# /dl-review — Convention-Driven Code Review

Review diffs against project conventions stored in memory. Every finding cites a specific convention or graph evidence — no opinions.

**Invoked as:** `/dl-review [--base <branch>] [--headless]`

---

## Gates: 0 (fully autonomous)

---

## Pre-flight (T1 Silent)

1. Check `.devline/` exists — if not: run in degraded mode (skip convention checks)
2. Check memory staleness: compare `config.json last_synced` vs `git rev-parse HEAD`
   - If stale: run `/dl-sync` (T1 Silent)
3. Confirm base branch: `git merge-base HEAD main` — default is `main` unless config specifies otherwise

---

## Phase 1 — Context Loading (T1 Silent)

1. Read `.devline/memory.md` (architecture + conventions)
2. Read full diff: `git diff <base>...HEAD`
   - If >30 files: read top 30 by node connectivity (run `dl-explain --rank --budget 30` and cross-reference with changed files)
3. For each changed file: `dl-explain --node <file>` → collect symbol names + inbound/outbound edges
4. Run `dl-explain --impact` → detect_changes blast radius for current diff

---

## Phase 2 — Convention Analysis

Apply the following checks. **Only flag if the relevant convention exists in memory.md or graph evidence is conclusive.** Never flag based on opinion.

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

## Phase 3 — Output

Group by severity: BLOCKING → WARNING → NOTE

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
