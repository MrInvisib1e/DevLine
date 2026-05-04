# DevFlow v3 — Comprehensive Improvement Design

**Date:** 2026-05-04
**Status:** Approved

---

## Executive Summary

DevFlow v3 is a comprehensive redesign of the Development-Flow skill system targeting four systemic problems: excessive interruption loops, imprecise skill instructions, fragile error propagation, and platform lock-in. The six design sections collectively reduce agent interruptions from ~12-15 per feature flow to ~3-4 strategic checkpoints, cut skill instruction token usage by ~43%, and eliminate known bugs in state tracking and status vocabularies. Memory infrastructure is upgraded from flat JSON + regex to SQLite + tree-sitter AST + PageRank, enabling large-repo scaling and deterministic graph traversal. The plugin architecture makes DevFlow a standalone, multi-platform package installable without manual file copying. All six plans are sequenced to build on each other, with memory infrastructure first as the foundational layer.

---

## Table of Contents

1. [Autonomy Tiers](#section-1-autonomy-tiers)
2. [Skill Instruction Quality](#section-2-skill-instruction-quality)
3. [Error Propagation & Feature Flow Resilience](#section-3-error-propagation--feature-flow-resilience)
4. [Standalone Plugin Architecture](#section-4-standalone-plugin-architecture)
5. [Agent Prompts & Output Validation](#section-5-agent-prompts--output-validation)
6. [Memory & Init Improvements](#section-6-memory--init-improvements)
7. [Execution Order](#execution-order)
8. [Dependencies](#dependencies)
9. [Risk Assessment](#risk-assessment)

---

## Section 1: Autonomy Tiers

### Problem

The blanket "propose 2-3 options, never decide for user" guard rail is applied uniformly across ALL skills, regardless of whether a decision is mechanical or high-stakes. This creates ~12-15 interruptions per feature flow, most of which add no value.

### Solution: 3-Tier Autonomy System

Replace the blanket guard rail with a 3-tier system defined in `skills/_shared.md` and referenced by each skill's Guard Rails section.

---

### T1 — Silent

**Rule:** Do it. No output. No waiting.

**For:** Mechanical, reversible, no judgment required.

**Examples:**
- Stack detection in init
- Staleness checks that pass
- File classification for obvious types (`*.test.ts` → test, `*.config.*` → config)
- Pre-flight checks that pass
- Workspace name detection

---

### T2 — Inform

**Rule:** Do it. Print one-line summary. Do not wait for confirmation.

**For:** Judgment with a clear default, reversible.

**Examples:**
- Memory sync results: `"Memory synced, 3 nodes updated"`
- Node inference in fix skill: `"Targeting auth-service node"`
- Hypothesis file list in fix: `"Reading 4 files: ..."`
- Any non-blocking concerns (replaces `DONE_WITH_CONCERNS` — see Section 3)
- df-sync results

---

### T3 — Gate

**Rule:** Present options. Wait for user input before proceeding.

**For:** Irreversible, high-stakes, or genuinely ambiguous.

**Examples:**
- PRD approval (Phase 0)
- Slice plan approval (Phase 2)
- Feature completion strategy (Phase 6)
- Plan approval (plan skill)
- Exhausted retry cycles (3 failures)
- Genuinely ambiguous file classification (truly unknown types)

---

### Per-Skill Gate Reduction

| Skill | Current Gates | Target Gates | Remaining Gate(s) |
|-------|--------------|--------------|-------------------|
| init | 3-5 | 1 | Final review summary |
| feature | ~12 | 3 | PRD, slices, completion |
| fix | 3 | 1 | Exhausted cycles only |
| review | 1-2 | 0 | Fully autonomous |
| plan | 1 | 1 | Plan approval (appropriate) |
| mem-sync | 1 | 0 | Fully autonomous |
| verify | 1 | 0 | Fully autonomous |

**Net result:** ~12-15 interruptions per feature flow → ~3-4 strategic checkpoints.

---

### Implementation

Each skill's Guard Rails section is rewritten. The "Decision protocol" guard rail changes from:

> "propose 2-3 options, never decide for user"

To a tier-specific rule referencing shared definitions in `skills/_shared.md`:

> "Apply autonomy tier from _shared.md: T1 (silent) for mechanical ops, T2 (inform) for clear defaults, T3 (gate) for irreversible/ambiguous."

---

## Section 2: Skill Instruction Quality

### 2a. Unified Status Model

Replace 3 different verdict systems across skills with 2 clean models:

| Agent Type | Valid Statuses |
|------------|---------------|
| **Executors** (implementation, test agents) | `DONE` \| `BLOCKED` |
| **Reviewers** (slice-review, integration, final-review) | `PASS` \| `FAIL` |

**Orchestrator decision table:**

| Agent Result | Tests Pass? | Action |
|--------------|------------|--------|
| `DONE` | yes | → send to reviewer |
| `DONE` | no | → `FAIL`, retry (max 3) |
| `BLOCKED` | — | → log, skip, continue |
| `PASS` | — | → proceed to next phase |
| `FAIL` | — | → retry with findings (max 3) |
| 3 retries exhausted | — | → mark stuck, T3 gate |

---

### 2b. Decision Tables Replace Prose

All conditional logic expressed as lookup tables, not paragraphs. Every decision point in every skill becomes a table row. No if/else prose descriptions.

---

### 2c. Default Actions

Every decision point gets a `DEFAULT:` line so the AI never freezes on an unhandled case.

**Example:**
```
| Condition | Action |
|-----------|--------|
| File has test in name | → classify as test |
| File has config in name | → classify as config |
| DEFAULT | → classify as source |
```

---

### 2d. Concrete Examples

Each skill gets a `## Examples` section with actual file paths, commands, and expected output. No abstract descriptions.

---

### 2e. Enforced Skill Chaining

YAML-style frontmatter in each `SKILL.md`:

```yaml
requires: [mem-sync]
triggers_on_complete: [verify]
```

Orchestrator reads frontmatter and enforces chaining automatically.

---

### 2f. Phase 3 State Tracking Fix

- Write `steps[].done = true` to slice JSON as slices complete
- Update `plan.md` with slice/batch/phase status after each batch
- Resume logic can reconstruct full state from these artifacts without guessing

---

### 2g. Structured Instruction Format (SIF)

Replace prose skill instructions with a token-efficient structured format:

**Rules:**
- No prose paragraphs — tables, lists, and code blocks only
- Shared patterns extracted to `skills/_shared.md` (~200 tokens), loaded once per session
- Lazy loading: only current phase/agent instructions in context at any time

**Token budget:**

| Component | Tokens |
|-----------|--------|
| `_shared.md` (once) | ~200 |
| Current phase instructions | ~200-300 |
| Agent-specific additions | ~80-100 |
| **Peak context** | **~580** |

**Total reduction:** ~5,950 → ~3,400 tokens (~43% savings).

---

### 2h. Maximum Precision Techniques

Seven techniques targeting four AI failure modes:

| Failure Mode | Techniques |
|-------------|-----------|
| Skips steps | Checkpoint Assertions, State Machine Dispatch |
| Misinterprets | WHY-Grounding |
| Drifts from task | Scope Fences, State Machine Dispatch, Rationalization Table Placement |
| Improvises beyond scope | Scope Fences, HALT with Exact Error Text, XML Semantic Wrapping |

**Technique details:**

**1. Checkpoint Assertions** (~10 tokens each)
```
CHECKPOINT: "[DevFlow] Hypothesis: {summary}"
```
Forces explicit step completion before proceeding.

**2. WHY-Grounding** (~10-15 tokens per rule)
Every critical rule appended with `— because {consequence}`.

**3. Scope Fences** (~30-40 tokens)
```xml
<scope>
EDIT: only hypothesis files.
DO NOT: refactor, add features, update deps
</scope>
```

**4. State Machine Dispatch** (~80-100 tokens for full feature flow)
Phase transitions as table rows, not prose descriptions.

**5. HALT with Exact Error Text** (~15-20 tokens per point)
```
NO → HALT. Print exactly: "DevFlow not initialized. Run /init first."
```

**6. Rationalization Table Placement** (~80-120 tokens)
Renamed to "You Will Be Tempted To". Placed AFTER steps, not before.

**7. XML Semantic Wrapping** (~5-10 tokens per block)
```xml
<iron-law>...</iron-law>
<scope>...</scope>
<rationalization-prevention>...</rationalization-prevention>
```

---

## Section 3: Error Propagation & Feature Flow Resilience

### Verified Bugs

| # | Bug | Severity |
|---|-----|----------|
| 1 | `steps[].done` never written by Phase 3 (resume checks it) | HIGH |
| 2 | Phase 3 doesn't write batch/phase progress to `plan.md` | MEDIUM |
| 3 | 4 different status vocabularies across agents | MEDIUM |
| 4 | `DONE_WITH_CONCERNS` "if correctness-blocking" is undefined | MEDIUM |
| 5 | No post-completion verification (test/build/lint) | HIGH |
| 6 | `finishing-a-development-branch` is external Superpowers dependency | MEDIUM |
| 7 | Phase 4 is thin (27 lines), no contract validation | MEDIUM |

---

### What's Fine — No Change

- **Phase 5 feedback loop** — already routes `CHANGES_REQUESTED` back to Phase 3, max 2 cycles
- **Phase 3 retry loop** — max 3 cycles with Prior Work context injection
- **Stuck slice handling** — blocks dependents, not independents

---

### 7 Fixes

**Fix 1: State Tracking** (+40 tokens)

After each slice verdict:
1. Write `steps[N].done = true` to slice JSON
2. Append progress table to `plan.md`

Resume can reconstruct exact state from these artifacts.

---

**Fix 2: Unified Status Model** (-60 tokens net)

Two models only:
- Executors: `DONE | BLOCKED`
- Reviewers: `PASS | FAIL`

Full orchestrator decision table replaces scattered status-handling prose.

---

**Fix 3: Kill DONE_WITH_CONCERNS** (-50 tokens)

`DONE_WITH_CONCERNS` eliminated entirely. Concerns are logged in agent output as T2 informational messages. The downstream reviewer decides if they are blocking.

---

**Fix 4: Post-Completion Verification Gate** (+60 tokens)

Phase 6, Step 1: Run `test_cmd`, `build_cmd`, `lint_cmd` from `config.json`.

| Result | Action |
|--------|--------|
| All pass | → proceed to completion |
| Test fails | → route back to Phase 3 |
| Build fails | → route back to Phase 3 |
| Lint fails | → T2 inform, proceed |
| Any fail, 3rd retry | → T3 gate |

---

**Fix 5: Inline Completion Logic** (-150 tokens net)

Replace external `finishing-a-development-branch` reference with DevFlow's own inline completion flow:

```
df-sync
→ archive plan (move to .devflow/plans/archive/)
→ T3 gate: present options (merge now / open PR / keep branch)
→ execute chosen option
→ record completion status in .devflow/history.json
```

---

**Fix 6: Phase 4 Contract Manifest** (+80 tokens)

Before dispatching integration agent, extract cross-slice interaction points:

1. Collect all exports from each slice's output files
2. Collect all imports referencing other slices
3. Build cross-reference table of interaction points
4. Pass manifest to integration agent as structured context

---

**Fix 7: Issue Fingerprinting** (+70 tokens)

Track fingerprints (`file:line:category` hash) across retry cycles.

| Classification | Condition | Action |
|---------------|-----------|--------|
| CLEAN | No issues remain | → proceed |
| PROGRESS | Fewer issues than last attempt | → continue retrying |
| MIXED | Some resolved, some new | → continue, escalate faster |
| STALLED | Same issues persist unchanged | → mark stuck immediately |
| REGRESSION | New issues appeared + old persist | → mark stuck immediately |

---

**Net token impact:** -10 tokens. Token-neutral, significantly more precise behavior.

---

## Section 4: Standalone Plugin Architecture

### Problem

DevFlow currently requires manual file copying and is bound to a single platform. There is no installation mechanism, no bootstrap skill, and no multi-platform manifest system.

### Solution: Plugin Package

DevFlow becomes a standalone npm-publishable package with platform-specific manifests, mirroring the Superpowers plugin pattern.

---

### File Structure

```
Development-Flow/
├── package.json                    # npm package with bin field
├── .opencode/plugins/devflow.js    # OpenCode plugin (config + message transform)
├── .claude-plugin/plugin.json      # Claude Code manifest
├── .cursor-plugin/plugin.json      # Cursor manifest
├── gemini-extension.json           # Gemini CLI manifest
├── GEMINI.md                       # Gemini skill reference
├── .codex/INSTALL.md               # Codex manual install
├── hooks/
│   ├── hooks.json                  # Claude Code hooks
│   ├── hooks-cursor.json           # Cursor hooks
│   ├── session-start               # Bootstrap script
│   └── run-hook.cmd                # Cross-platform hook wrapper
├── skills/
│   ├── using-devflow/SKILL.md      # NEW: bootstrap skill (~200-300 tokens)
│   ├── _shared.md                  # NEW: shared patterns (~200 tokens)
│   ├── init/SKILL.md
│   ├── feature/...
│   ├── fix/SKILL.md
│   ├── mem-sync/SKILL.md
│   ├── review/SKILL.md
│   ├── plan/SKILL.md
│   └── verify/SKILL.md
└── bin/
    ├── df-init, df-sync, df-test
    ├── df-workspace, df-explain
    ├── df-export, df-resolve
```

---

### Bootstrap Skill (`using-devflow/SKILL.md`)

~200-300 tokens. The only skill loaded on session start. Does exactly three things:

1. Announce DevFlow is active in this session
2. Tell the AI how to discover and invoke skills
3. Set Iron Law: check `.devflow/` before any DevFlow operation

---

### Platform Delivery

| Platform | Mechanism | Key File |
|----------|-----------|----------|
| OpenCode | Plugin injects bootstrap skill into first message. Registers skills dir. Adds `bin/` to PATH. | `.opencode/plugins/devflow.js` |
| Claude Code | SessionStart hook → `session-start` script → JSON with `additionalContext` | `.claude-plugin/plugin.json` + `hooks/hooks.json` |
| Cursor | Same pattern as Claude Code | `.cursor-plugin/plugin.json` + `hooks/hooks-cursor.json` |
| Gemini CLI | Extension manifest + GEMINI.md (skill ref + tool mapping) | `gemini-extension.json` + `GEMINI.md` |
| Codex | Manual clone + symlink documented | `.codex/INSTALL.md` |

---

### Token Budget

| Component | Tokens | When Loaded |
|-----------|--------|-------------|
| Bootstrap skill | ~200-300 | Always (session start) |
| Individual skill | ~200-400 | On-demand |
| Peak context | ~600-800 | Active skill execution |

60-70% reduction from current always-in-context approach.

---

### Installation Commands

| Platform | Command |
|----------|---------|
| OpenCode | `{"plugin": ["devflow@git+https://github.com/<user>/Development-Flow.git"]}` |
| Claude Code | `/plugin install devflow@claude-plugins-official` |
| Cursor | `/add-plugin devflow` |
| Gemini | `gemini extensions install <url>` |
| Codex | Manual clone + symlink (see `.codex/INSTALL.md`) |

---

## Section 5: Agent Prompts & Output Validation

### Part A: Structured Prompt Templates

New directory: `skills/feature/agents/prompts/`

Each template follows research-validated prompt ordering:

1. Identity / Role
2. Mission (one sentence)
3. Scope Fence (`<scope>` tag with exact file list + prohibitions)
4. Context (injected project data — long docs before task)
5. Prior Work (only on retry: last attempt + structured feedback)
6. Output Contract (exact format required)

---

### Template Specifications

| Template | Role | Key Scope Rule | Output Format |
|----------|------|----------------|---------------|
| `impl.md` | Implementation agent | `<scope>` allowlist from slice JSON | `status: DONE\|BLOCKED`, `files_changed[]`, `summary` |
| `test.md` | Test agent | Read slice code + write test files only | `status: DONE\|BLOCKED`, `test_files[]`, `coverage_notes` |
| `slice-review.md` | Slice reviewer | **Read-only.** Report all, filter downstream. | `verdict: PASS\|FAIL`, `findings[]` with file/line/severity |
| `integration.md` | Integration tester | Read all slice outputs, write integration tests | `verdict: PASS\|FAIL`, `contract_violations[]`, `responsible_slices{}` |
| `final-review.md` | Final reviewer | **Read-only. Fresh context only** (no build history) | `verdict: PASS\|FAIL`, `findings[]`, `blocking_issues[]` |

**Key design decisions:**
- Scope fence mandatory in every template — because agents without scope boundaries edit adjacent code
- Reviewers explicitly told "report all findings, filter downstream" — because self-filtering loses issues
- Final reviewer gets fresh context only (requirements + final code + test results, no fix history) — because history biases toward accepting known-bad patterns
- Prior Work injected only on retry — saves tokens on first attempt

---

### Part B: Output Validation Pipeline

Runs after every agent response, before the orchestrator accepts a result. Zero LLM cost for all checks.

| # | Check | Catches | Failure Type |
|---|-------|---------|-------------|
| 1 | Output format valid | Malformed/partial responses | HARD REJECT |
| 2 | File paths exist (filesystem check) | Hallucinated file references | HARD REJECT |
| 3 | Scope check (`git diff` vs allowlist) | Scope creep | HARD REJECT |
| 4 | Non-empty check (`git diff --stat`) | No-op submissions | HARD REJECT |
| 5 | Incomplete signal scan (`TODO`, `pass`, `NotImplemented`) | Stub/placeholder code | SOFT RETRY |
| 6 | Static analysis (`tsc --noEmit` / linter) | Broken imports, type errors | SOFT RETRY |
| 7 | Test execution (`test_cmd` from config) | Actual runtime bugs | SOFT RETRY |
| 8 | Slop score (prose-to-code ratio) | Generic/unhelpful output | SOFT RETRY |

**Routing:**
- HARD REJECT → retry with specific format/scope reminder (max 3)
- SOFT RETRY → retry with specific failure feedback (max 3)
- All pass → PROCEED to next pipeline stage
- `retry_count >= 3` → mark STUCK, T3 gate

---

### Part C: Issue Fingerprinting

Fingerprint format: `SHA256(file:line:category)`.

After each retry, classify the fingerprint delta:

| Classification | Condition | Action |
|---------------|-----------|--------|
| CLEAN | No issues remain | → proceed |
| PROGRESS | Fewer issues than last attempt | → continue |
| MIXED | Some resolved, some new | → continue, escalate faster |
| STALLED | Same fingerprints persist unchanged | → mark stuck immediately |
| REGRESSION | New fingerprints + old persist | → mark stuck immediately |

---

### Part D: Prompting Skill (`/prompt`) — Optional

Workflow: classify task type → load template → fill with memory context → apply precision techniques → output prompt.

---

## Section 6: Memory & Init Improvements

### 6a. Zero-Question Init

Replace 3-5 approval gates with a single final summary gate:

| Operation | Old Tier | New Tier | Change |
|-----------|----------|----------|--------|
| Stack detection | T3 (ask) | T1 (silent) | Auto-detect, no prompt |
| Workspace name | T3 (ask) | T1 (silent) | Auto-detect |
| File classification (obvious) | T3 (ask) | T1 (silent) | Expanded classifiers |
| Final review summary | T3 (ask) | T3 (gate) | Single approval point |

Result: One gate instead of 3-5.

---

### 6b. Tree-sitter AST Extraction

Replaces current bash regex classifiers in `df-sync`.

**Why tree-sitter:** Language-aware, deterministic, free, supports 25+ languages, handles nested scopes and multi-line expressions correctly.

**Extracted data:**
- Symbol definitions (classes, functions, methods)
- Import relationships → EXTRACTED edges
- Call sites → EXTRACTED or INFERRED edges
- Inline documentation comments

---

### 6c. Two-Level Content Hashing

Replaces timestamp-based staleness detection.

| Level | Hash Input | Purpose |
|-------|-----------|---------|
| 1 | `SHA256(file content)` | Detect any change |
| 2 | `SHA256(exported API / public interface)` | Detect API-breaking changes only |

Stored in `.devflow/cache/content-hashes.json`.

**Behavior:** Skip unchanged files even if git lists them. API-level changes propagate to dependents. Internal implementation changes do not.

---

### 6d. Quick Sync for Hooks

| Mode | Speed | Used By |
|------|-------|---------|
| `df-sync --quick` | ~100ms (small repos) | Post-commit git hook |
| `df-sync` (full) | ~5-60s | Explicit call, skill trigger |

---

### 6e. Confidence Labels on Edges

Replace binary `source: "static"|"ai"` with a three-tier confidence system:

| Label | Source | Confidence | Examples |
|-------|--------|-----------|---------|
| EXTRACTED | AST (tree-sitter) | 1.0 | Explicit imports, direct calls |
| INFERRED | AI classification | 0.55-0.95 | Semantic relationships, indirect deps |
| AMBIGUOUS | Uncertain | < 0.55 | Flagged for review |

---

### 6f. PageRank-Ranked Context Generation

Replaces current `df-explain` BFS traversal and vague "god node" heuristic.

**Algorithm (adapted from Aider):**
1. Build reference graph from tree-sitter extraction
2. Run PageRank — highest-centrality nodes = most important for LLM context
3. Greedy token-budget selection (default ~1K tokens for repo map)
4. Dynamic budget: expand when no files in chat, contract when files are added

**Additional features:**
- `df-explain --diff <sha1> <sha2>` — graph diff between two states
- Surprising connections — cross-community edges ranked by surprise score

---

### 6g. SQLite Graph Store

Replaces flat `nodes.json` + `edges.json` + `jq` pipeline.

**Schema:**
```sql
CREATE TABLE nodes (
  id TEXT PRIMARY KEY, kind TEXT, name TEXT,
  file_id TEXT, line INT, col INT
);
CREATE TABLE edges (
  source TEXT, target TEXT, kind TEXT, confidence REAL,
  PRIMARY KEY (source, target, kind)
);
CREATE INDEX idx_edges_target ON edges(target);
CREATE INDEX idx_nodes_name ON nodes(name);
CREATE INDEX idx_nodes_file ON nodes(file_id);
```

**Benefits:**
- O(log n) lookups vs O(n) JSON scan
- Concurrent readers via WAL mode
- Recursive CTEs for affected-set computation
- Single-file deployment: `.devflow/graph.db`

---

### 6h. Large Repo Scaling

**Batch staleness check:** Single `git log --name-only` + SQLite query.
- 500 nodes: ~50-100s → ~200ms

**Auto-scope from git diff (Nx/Turborepo pattern):**
```
git diff --name-only → map to nodes → reverse BFS → minimal affected set
```

**memory.md tiered rendering:**
- Top ~30-50 PageRank nodes in summary (~2,500 tokens, capped)
- Full graph on demand via `df-explain`

**Projected performance:**

| Operation | Small (<200 files) | Medium (200-2K) | Large (2K-10K) |
|-----------|-------------------|-----------------|----------------|
| `df-sync --quick` | ~100ms | ~500ms | ~2s |
| `df-sync` (full) | ~5s | ~15s | ~30-60s |
| `df-explain` | ~50ms | ~100ms | ~200ms |
| `memory.md` tokens | ~1,000 | ~2,500 | ~2,500 (capped) |

**Implementation priority:** SQLite → tree-sitter → PageRank → two-level hashing → auto-scope → confidence scores

---

## Execution Order

Plans are sequenced so each builds on the infrastructure of the previous:

```
Plan 6: Memory & Init
  SQLite graph store, tree-sitter AST, PageRank context,
  zero-question init, large-repo scaling
  ↓
Plan 1: Autonomy Tiers
  T1/T2/T3 across all skills, _shared.md definitions,
  per-skill gate reduction
  ↓
Plan 2: Skill Instruction Quality
  SIF format, decision tables, precision techniques,
  skill chaining frontmatter
  ↓
Plan 3: Error Propagation
  State tracking fix, unified status, fingerprinting,
  post-completion verification, inline completion
  ↓
Plan 5: Agent Prompts & Validation
  Prompt templates, output validation pipeline,
  prompting skill
  ↓
Plan 4: Plugin Architecture
  Bootstrap skill, multi-platform manifests,
  npm package, installation
```

**Rationale:**
- Plan 6 first: graph store is foundational; all other plans reference `.devflow/` structure
- Plan 1 before 2: tiers defined in `_shared.md` before skills are rewritten in SIF format
- Plan 2 before 3: unified status model required for error propagation fixes
- Plan 3 before 5: fingerprinting system referenced by prompt templates
- Plan 4 last: plugin wraps everything; skills must be finalized first

---

## Dependencies

```
Plan 6 (Memory & Init)
  └── No dependencies — foundational layer

Plan 1 (Autonomy Tiers)
  └── Requires: Plan 6 (_shared.md location, .devflow/ structure finalized)

Plan 2 (Skill Instruction Quality)
  └── Requires: Plan 1 (T1/T2/T3 in _shared.md)
  └── Requires: Plan 6 (SQLite, so state tracking examples are concrete)

Plan 3 (Error Propagation)
  └── Requires: Plan 2 (unified status model in SIF format)
  └── Requires: Plan 6 (SQLite for fingerprint storage)

Plan 5 (Agent Prompts & Validation)
  └── Requires: Plan 3 (unified status model, fingerprinting)
  └── Requires: Plan 2 (SIF format for prompt templates)

Plan 4 (Plugin Architecture)
  └── Requires: All other plans (skills finalized before packaging)
```

**Shared artifacts:**

| Artifact | Created By | Used By |
|----------|-----------|---------|
| `skills/_shared.md` | Plan 1 | Plans 2, 3, 4, 5 |
| Unified status model | Plan 2 | Plans 3, 5 |
| `.devflow/graph.db` schema | Plan 6 | Plans 2, 3, 5 |
| Fingerprint system | Plan 3 | Plan 5 |
| Prompt templates | Plan 5 | Plan 4 (packaged) |
| SIF format spec | Plan 2 | Plans 3, 4, 5 |

---

## Risk Assessment

### Plan 6 — Memory & Init

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| SQLite not available in some environments | Low | High | Bundle `better-sqlite3`; JSON fallback for read-only ops |
| Tree-sitter grammar gaps for uncommon languages | Medium | Medium | Graceful fallback to regex classifier |
| PageRank unstable for small repos (<20 files) | Medium | Low | Minimum node threshold; BFS fallback below threshold |
| SHA256 API fingerprint extraction too fragile | Medium | Medium | Level 2 hash optional; degrade to Level 1 |
| Auto-scope misses transitive dependencies | Medium | High | Err toward over-inclusion; configurable depth limit |

### Plan 1 — Autonomy Tiers

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| T1/T2 misclassifications cause silent bad decisions | Medium | High | Err toward T2 over T1 when uncertain; session audit log |
| Users feel loss of control | Medium | Medium | `--interactive` flag upgrades all T2→T3 |
| AI ignores tier rules | Low | Low | Tier rules in `<iron-law>` XML tags |

### Plan 2 — Skill Instruction Quality

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| SIF too rigid for complex edge cases | Medium | Medium | Prose allowed only in `## Examples` section |
| AI ignores decision tables | Medium | High | Checkpoint Assertions force table consultation |
| Token reduction breaks skill completeness | Low | High | Measure before/after on real flows; coverage checklist |
| Skill chaining frontmatter not honored | Medium | Medium | Checkpoint at skill start: AI prints required chain |

### Plan 3 — Error Propagation

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| State tracking writes fail mid-slice | Medium | Medium | Write after verdict confirmed; atomic SQLite transactions |
| Fingerprint hash collisions → false STALLED | Very Low | Medium | Timestamp salt if collision detected |
| Killing DONE_WITH_CONCERNS loses signals | Low | High | Reviewer explicitly checks for concern patterns in output |
| Post-completion verification too slow | Medium | Medium | Parallel execution of test/build/lint |

### Plan 5 — Agent Prompts & Validation

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Validation pipeline adds latency | Low | Low | All checks are filesystem/git ops; zero LLM calls |
| Scope fence too restrictive | Medium | Medium | Scope fence generated from T3-approved slice JSON |
| Slop score too noisy | Medium | Low | Check 8 is lowest priority; never blocks alone |
| Prompt templates drift from skill updates | Medium | Medium | Templates co-located; update protocol in `_shared.md` |

### Plan 4 — Plugin Architecture

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Platform plugin APIs change | Medium | High | Thin plugin layer (~50 lines); version-pin in manifests |
| npm global install unavailable | Medium | Low | PATH fallback in bootstrap skill |
| Multi-platform testing surface large | High | Medium | OpenCode + Claude Code primary; Cursor/Gemini secondary |
| Session-start hook timing issues | Low | Medium | Bootstrap is idempotent; re-announcing is harmless |

---

*Document generated: 2026-05-04 | DevFlow v3 Design Phase | All 6 sections approved for implementation*
