---
name: devflow-review
description: Convention-driven code review using DevFlow memory context
requires: [mem-sync]
triggers_on_complete: []
---

# Skill: review

# DevFlow Review

Review a diff against project conventions stored in graph memory. Reads memory before diff, runs df-explain on every changed node, flags convention violations, and reports an impact radius.

**Invoked as:** `/review` or `/review --base <ref>`

---

## Quick Reference

| Command | What it does |
|---------|-------------|
| `/review` | Review diff of current branch vs `main` (falls back to `master`) |
| `/review --base <ref>` | Review diff of current branch vs specified ref (branch, tag, or SHA) |

---

## The Iron Law

```
CONVENTIONS, NOT OPINIONS. MEMORY BEFORE DIFF. ALWAYS.
```

Convention not in memory.md → not a finding. Haven't read memory.md → can't review.

---

## Pre-Flight

Run these checks before any analysis. Do not proceed if any fail (unless noted).

### Step 0 — Prerequisites

Check if `.devflow/` exists:

```bash
ls .devflow/active/memory.md 2>/dev/null
```

If `.devflow/` does not exist: enter **Degraded Mode** (see section below). Skip Steps 1–2, proceed to Step 3.

If `.devflow/` exists, verify required tools are on PATH:

```bash
which df-explain
which df-sync
```

If either is missing: print `[DevFlow] Required tool not found: <tool>. Add DevFlow bin/ to PATH.` and stop.

### Step 1 — Conflict Check

Check if `.devflow/active/graph_conflicts.json` exists:

```bash
ls .devflow/active/graph_conflicts.json 2>/dev/null
```

If it exists: load all conflicted node IDs into a set. Print:

```
[DevFlow] Unresolved graph conflicts detected.
Conflicted nodes: <list node ids>
Review will proceed — findings touching these nodes are tagged [contested-intent].
```

Do NOT halt. Proceed with review, tagging any finding that touches a conflicted node with `[contested-intent]`.

### Step 2 — Staleness Check

Read `.devflow/config.json`. Compare `last_synced` to current HEAD and check `dirty` flag:

```bash
git rev-parse HEAD
```

If `dirty == true` OR `last_synced != HEAD`:

```bash
df-sync
```

Print: `[DevFlow] Memory was stale — synced to <sha> before proceeding.`

If `df-sync` fails: print `[DevFlow] df-sync failed (exit <code>). Review may use stale memory.` Proceed with warning — do not halt.

### Step 3 — Diff Validation

Resolve the base ref:

```bash
git rev-parse --verify <base-ref> 2>/dev/null
```

If `--base` was provided and the ref is invalid: print `[DevFlow] Bad base ref: <ref>` and stop (E04).

If `--base` was not provided: try `main`, then `master`. If neither exists: print `[DevFlow] No default base branch found (tried main, master).` and stop (E04).

Generate the diff:

```bash
git diff <base-ref>...HEAD --name-status
```

If the diff is empty: print `[DevFlow] No changes between HEAD and <base-ref>. Nothing to review.` and exit 0 (E08).

Categorize files into: **added (A)**, **modified (M)**, **deleted (D)**.

---

## Phase 1 — Context Loading

Load context in this exact order. Do NOT begin analysis until all context is loaded.

### 1.1 — Read Memory

Read `.devflow/active/memory.md`. Extract and internalize:

- **Architecture section** — service boundaries, communication patterns, layer structure
- **Conventions section** — naming rules, DI lifetime rules, test requirements, and any other project-specific conventions

If `memory.md` is empty or has no architecture/conventions sections: print `[DevFlow] memory.md has no conventions — review will be convention-unaware.` Continue with generic diff review only (E07).

### 1.2 — Read Diff

Read the full diff:

```bash
git diff <base-ref>...HEAD
```

If the diff is ≤ 30 files: read fully.

**Large diff handling (>30 files):** First run Phase 1.3 (node resolution) across all changed files to determine connectivity. Then read the full diff only for the top 30 files by total edge count (inbound + outbound). For remaining files, use the `--name-status` summary only. Print: `[DevFlow] Large diff (N files). Full analysis on top 30 by connectivity; summary for remaining.`

### 1.3 — Node Resolution

For each changed file, run:

```bash
df-explain --node <file-path> --depth 1
```

Collect from each result:
- Node ID, type, intent
- Outbound edges (DEPENDS ON)
- Inbound edges (DEPENDED ON BY)
- Whether the node is marked STALE

Track files that return no match — these are **unclassified files**.

If `df-explain` fails on a specific file: log the file, continue with remaining files (E06). Print: `[DevFlow] df-explain failed for <file> — skipping node analysis for this file.`

### 1.4 — Build Review Context

Assemble a mental review context document containing:

1. **Conventions** — all rules extracted from memory.md
2. **Architecture** — service boundaries, communication patterns
3. **Conflicted nodes** — set of node IDs with contested intent values (from Step 1)
4. **Changed nodes** — each with type, intent, inbound edges, outbound edges
5. **Unclassified files** — files with no graph node
6. **Full diff** — the actual code changes (top 30 by connectivity for large diffs; summary for the rest)

---

## Phase 2 — Analysis

Apply checks against the review context. Each check is **convention-driven** — only apply a check if the relevant convention exists in memory.md.

### Default Checks

| # | Check | Default Severity | Apply when |
|---|-------|-----------------|------------|
| 1 | Service communication violations | BLOCKING | Architecture defines communication patterns (e.g., async messaging vs direct HTTP) |
| 2 | DI lifetime mismatches | BLOCKING | Conventions define DI lifetime rules (e.g., scoped vs singleton) |
| 3 | Naming deviations | WARNING | `conventions.naming` section exists in memory.md |
| 4 | Missing test coverage | WARNING | New functionality added without corresponding test files in diff |
| 5 | Contract changes without memory update | WARNING | Public interface changed but memory.md not updated in diff |
| 6 | Unclassified files | NOTE | Any changed file has no graph node |
| 7 | Impacted inbound nodes | NOTE | Nodes that depend on changed nodes but are not themselves in the diff |

### Convention-Driven Extras

If memory.md contains conventions beyond the 7 defaults (e.g., error handling patterns, logging standards, API versioning rules), apply those as additional checks with WARNING severity.

### Contested-Intent Tagging

Any finding that touches a node present in the conflicted node set must be tagged `[contested-intent]`. The tag signals: this finding may be invalid because the node's intent is disputed. The developer should run `df-resolve` before acting on it.

If ALL changed nodes are conflicted: print `[DevFlow] All changed nodes have contested intent. All findings are tagged [contested-intent] — run df-resolve for reliable review.` Proceed with all findings tagged.

### Analysis Rules

- **Conventions, not opinions.** Every finding must cite a specific convention from memory.md or a specific graph relationship. Never flag something because it "looks wrong" without a convention backing it.
- **Memory before diff.** You already loaded memory first (Phase 1.1). Do not re-read memory during analysis.
- **No false precision.** If a convention is ambiguous, flag it as NOTE, not BLOCKING.
- **Read-only.** Do not modify any files. Do not suggest fixes — only flag violations.

---

**REQUIRED:** Before reporting verdict, follow `skills/verify/SKILL.md`.

## Output Format

Print the review in this exact structure:

### Summary

2–3 sentences describing what the diff does and the overall review result.

### Findings

Group by severity, highest first. Each finding:

```
[BLOCKING] <check-name>: <description>
  File: <file-path>
  Convention: "<quoted convention from memory.md>"
  Context: <relevant code snippet or node relationship>
  [contested-intent]  ← only if node is conflicted
```

```
[WARNING] <check-name>: <description>
  File: <file-path>
  Convention: "<quoted convention from memory.md>"
  Context: <relevant detail>
```

```
[NOTE] <check-name>: <description>
  File: <file-path>
  Detail: <explanation>
```

If no findings in a severity level, omit that section entirely.

If no findings at all: print `No findings.`

### Impact Radius

List inbound nodes that depend on changed nodes but are NOT in the diff:

```
Nodes potentially affected by this change (not in diff):
  ← <NodeName> [<type>] — <intent summary>
  ← <NodeName> [<type>] — <intent summary>
```

If no impacted inbound nodes: print `No external impact detected.`

### Verdict

One of three verdicts:

| Verdict | Condition |
|---------|-----------|
| **PASS** | No BLOCKING findings AND ≤ 2 WARNING findings |
| **CONCERNS** | No BLOCKING findings AND ≥ 3 WARNING findings |
| **BLOCKING** | Any BLOCKING finding exists |

Print:

```
Verdict: <PASS|CONCERNS|BLOCKING>
  BLOCKING: <count>
  WARNING:  <count>
  NOTE:     <count>
```

---

## Degraded Mode

When `.devflow/` does not exist (e.g., CI environment without DevFlow initialized):

1. Print: `[DevFlow] No .devflow/ directory found. Running in degraded mode — convention-unaware review only.`
2. Skip Steps 1–2 of pre-flight (no config.json to read). Run Step 3 (diff validation) normally.
3. Skip Phase 1.1 (no memory to read) and Phase 1.3 (no nodes to resolve).
4. In Phase 2: skip all convention-driven checks (1–5). Provide general diff observations without severity tags — descriptive notes only.
5. Output format: Summary + general observations. No verdict.

Degraded mode is a fallback, not a feature. The review is significantly less useful without graph memory.

---

## Error Reference

| Code | Condition | Behaviour |
|------|-----------|-----------|
| E01 | `df-explain` not on PATH | Print message, stop |
| E02 | `df-sync` not on PATH | Print message, stop |
| E03 | `.devflow/` missing | Enter degraded mode — not a hard error |
| E04 | Bad `--base` ref or no default base branch found | Print message, stop |
| E05 | `df-sync` fails | Print warning, proceed with potentially stale memory |
| E06 | `df-explain` fails for a specific file | Log file, skip node analysis for that file, continue |
| E07 | `memory.md` empty or missing architecture/conventions | Print warning, proceed with convention-unaware review |
| E08 | Empty diff | Print message, exit 0 |

---

## Guard Rails

- **Memory before diff.** Always read `memory.md` before examining any code changes. — because reviewing without context produces opinion-based findings, not convention-based ones.
- **Conventions, not opinions.** Every finding must reference a specific convention or graph relationship from memory.
- **Read-only.** This skill never modifies files, suggests fixes outside findings, or creates commits.
- **T2 for ambiguity.** Ambiguous convention interpretation → T2 Inform with assumption stated. Do not pause.
- **No T3 gates.** This skill is fully autonomous. See `skills/_shared.md`.
- **Large diff handling.** If diff has >30 nodes: focus on top 30 by connectivity score from `df-explain`. T2 inform: `[DevFlow] Large diff — focusing on top 30 nodes by connectivity.`
- **Reality check.** Correct, working, conventional code → no finding. Don't invent problems.

---

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
| "Convention ambiguous" | T2 Inform with assumption. Don't pause for input. |

## Red Flags — STOP

- Flagging something not backed by convention in memory.md
- Skipping df-explain on a changed file
- Reading diff before reading memory.md
- Applying generic best practices instead of project conventions
- Resolving contested-intent instead of tagging it
- Claiming PASS without checking impact radius
- Flagging code that works and follows conventions

**Stop. Re-read guard rails. Follow the process.**

---

## Notes

- This skill is standalone — it is not used by the feature skill, which has its own review agents.
- In CI pipelines, the absence of `.devflow/` triggers degraded mode, not an error.
- The review does not suggest fixes. It identifies violations and surfaces impact. The developer decides what to do.
- Running `df-resolve` before `/review` produces more reliable output when conflicts exist.
