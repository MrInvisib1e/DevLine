# DevFlow Review Skill — Design Spec

**Date:** 2026-05-01  
**Status:** Approved  
**Skill location:** `skills/review/SKILL.md`

---

## Overview

The `/review` skill reviews a diff against project conventions stored in graph memory. It reads `memory.md` before examining any code changes, runs `df-explain` on every changed node to understand the impact radius, then flags violations of actual project conventions (not generic best practices). Output is a structured finding report with a PASS / CONCERNS / BLOCKING verdict.

This is a standalone skill — it is not used by the feature skill, which has its own review agents.

---

## Invocation

```
/review
/review --base <ref>
```

- **Default base:** `main`, falling back to `master`
- **Custom base:** any valid git ref (branch, tag, SHA)
- **Empty diff:** exits 0 silently with a message

---

## Design Decisions

### 1. Diff target
User-specified `--base <ref>`. Defaults to `main`, falls back to `master`. If neither default exists and no `--base` is given, stop with E04.

### 2. Severity model
Three-tier, matching the feature skill: `BLOCKING / WARNING / NOTE`. Verdict thresholds: PASS (no blocking, ≤2 warnings), CONCERNS (no blocking, 3+ warnings), BLOCKING (any blocking finding).

### 3. Standalone only
Not dual-use with the feature skill. Feature has its own review agents (slice-review.md, final-review.md). This skill is for standalone PR/branch review outside of active feature slices.

### 4. CI / degraded mode
If `.devflow/` does not exist (e.g., uninitialized repo, CI without DevFlow): enter degraded mode — convention-unaware review with general observations only. No verdict. Not an error.

### 5. Check strategy
Convention-driven: 7 default checks from §10 of the spec. Checks are skipped when the relevant memory section is missing. Additional conventions from `memory.md` beyond the 7 defaults are applied as WARNING-severity extras.

### 6. Approach
Two-phase: **Context Loading** (pre-flight → memory → diff → node resolution) → **Analysis** (apply checks → output).

---

## Architecture

### Pre-Flight (Steps 0–3)

Four sequential checks before any analysis:

0. **Prerequisites** — `df-explain` and `df-sync` on PATH; detect `.devflow/` presence (degraded mode if missing)
1. **Conflict check** — load `graph_conflicts.json`, collect conflicted node IDs into a set; tag findings rather than halt
2. **Staleness check** — compare `last_synced` vs HEAD and `dirty` flag; auto-run `df-sync` if stale
3. **Diff validation** — resolve base ref, generate `git diff --name-status`, exit 0 on empty diff

### Phase 1 — Context Loading

Load all context before any analysis begins:

1. **Read memory** — `memory.md` architecture + conventions sections
2. **Read diff** — full diff; large diff handling for >30 files (top 30 by connectivity, summary for rest)
3. **Node resolution** — `df-explain --depth 1` on each changed file; collect inbound/outbound edges; track unclassified files
4. **Build review context** — mental document: conventions + architecture + conflicted nodes + changed nodes with edges + unclassified files + full diff

### Phase 2 — Analysis

Apply 7 default checks (convention-driven, skip if relevant convention absent):

| # | Check | Severity | Condition |
|---|-------|----------|-----------|
| 1 | Service communication violations | BLOCKING | Architecture defines comm patterns |
| 2 | DI lifetime mismatches | BLOCKING | Conventions define DI rules |
| 3 | Naming deviations | WARNING | `conventions.naming` section exists |
| 4 | Missing test coverage | WARNING | New slice/functionality without tests |
| 5 | Contract changes without memory update | WARNING | Public interface changed, memory not updated |
| 6 | Unclassified files | NOTE | Files with no graph node |
| 7 | Impacted inbound nodes | NOTE | Dependent nodes not in diff |

Any convention in `memory.md` beyond these 7 is applied as an additional WARNING check.

Any finding touching a conflicted node gets `[contested-intent]` tag.

### Output Structure

```
Summary (2–3 sentences)

[BLOCKING] ...  ← grouped by severity, highest first
[WARNING] ...
[NOTE] ...

Impact Radius: inbound nodes not in diff

Verdict: PASS | CONCERNS | BLOCKING
  BLOCKING: N
  WARNING: N
  NOTE: N
```

---

## Error Reference

| Code | Condition | Behaviour |
|------|-----------|-----------|
| E01 | `df-explain` not on PATH | Stop |
| E02 | `df-sync` not on PATH | Stop |
| E03 | `.devflow/` missing | Degraded mode |
| E04 | Bad `--base` ref or no default | Stop |
| E05 | `df-sync` fails | Warn, continue with stale memory |
| E06 | `df-explain` fails for a file | Skip that file, continue |
| E07 | `memory.md` empty or no conventions | Warn, convention-unaware review |
| E08 | Empty diff | Exit 0 |

---

## Edge Cases

- **Large diffs (>30 files):** Full analysis on top 30 by graph connectivity (inbound + outbound edges); summary for the rest.
- **No nodes resolve:** Convention-aware but not graph-aware. Treat all files as unclassified (CHECK 6 fires for all).
- **All nodes conflicted:** Print a warning, proceed with all findings tagged `[contested-intent]`.
- **df-explain fails for all files:** Log all failures, continue with convention-only review (no impact radius).

---

## Guard Rails

1. **Memory before diff.** `memory.md` is always read before examining any code changes.
2. **Conventions, not opinions.** Every finding must cite a specific convention from `memory.md` or a specific graph relationship.
3. **Read-only.** This skill never modifies files, suggests fixes, or creates commits.
4. **No false precision.** Ambiguous conventions produce NOTE findings, not BLOCKING.
5. **Contested nodes always tagged.** Any finding touching a conflicted node gets `[contested-intent]`.
6. **Large diffs are bounded.** Full analysis on top 30 files by connectivity; summary for the rest.

---

## Skill Structure

Single file: `skills/review/SKILL.md` (~280 lines). No agent templates required — the review is performed inline by the invoking agent.
