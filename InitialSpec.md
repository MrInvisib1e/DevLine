# DevFlow — Design Spec
**Date:** 2026-04-29  
**Status:** Revised  
**Approach:** Option A — Skills + Shell Scripts

---

## 1. Vision

DevFlow is a Claude Code skill library that makes AI behave like a senior engineer — not an order-taker. It is stack-agnostic, general-purpose, and built around three principles:

1. **Domain first** — interrogate intent and constraints before writing a line of code
2. **Vertical slices** — every feature increment spans all needed layers and produces a testable result
3. **Accurate context** — AI maintains a machine-readable codebase model per developer, per branch, self-correcting as code evolves

---

## 2. Skills

| Skill | Trigger | Purpose |
|---|---|---|
| `init` | Once per repo | Scan codebase, build memory, register in workspace |
| `domain` | Before any feature | Expert interrogation — intent, edge cases, constraints |
| `feature` | Main coding loop | Vertical slice execution with per-slice test gates |
| `mem-sync` | After every commit | Diff-based memory update — patches `memory.json`, `nodes.json`, `edges.json`, regenerates `memory.md` |
| `fix` | Failing test or bug | Systematic debug using live memory context |
| `review` | Before merge | Architecture-aware code review against memory conventions |

---

## 3. Shell Scripts

Six bash scripts handle all mechanical operations. Installed once globally.

```
~/.devflow/bin/
  df-init        # scan repo, build initial memory, register in workspace
  df-sync        # diff HEAD vs last SHA, classify changes, patch memory.json, regenerate memory.md
  df-test        # read slices.json, run declared test for a named slice, report PASS/FAIL/ERROR
  df-workspace   # manage workspace registry (add/remove/list/read)
  df-explain     # given a file path or symbol, print which memory sections describe it
  df-export      # dump current memory as a CLAUDE.md-compatible markdown block
```

Scripts output structured text. Skills read that output and reason on top of it. The AI never manually parses git.

---

## 4. Memory Architecture

### Design Principle

Memory is **machine-first**. It is not designed to be read or edited by humans directly. `memory.json` is the source of truth. `memory.md` is a read-only render generated automatically by `df-sync` — it is what skills read.

### Location & Scope

Memory is **gitignored** and **local per developer**. Each developer builds their own memory via `df-init` and keeps it current via `df-sync`. No shared memory in git — no merge conflicts, no cross-developer pollution.

### Branch-Scoped Directories

Each branch gets an isolated memory snapshot:

```
.devflow/
  config.json
  branches/
    main/
      memory.json      # source of truth — owned by df-sync
      memory.md        # auto-generated render — read by skills
      slices.json      # active slice plan — written by feature skill, consumed by df-test
    feature-comments/
      memory.json
      memory.md
      slices.json
  active -> branches/feature-comments/    # symlink, swapped on checkout
```

Skills always read from `.devflow/active/` — they are branch-unaware by design.

### memory.json Schema

```json
{
  "schema_version": 1,
  "last_synced": "a3f9c12",
  "stack": {
    "runtime": "dotnet-9",
    "frontend": "sveltekit",
    "test_cmd": "dotnet test",
    "key_dependencies": []
  },
  "architecture": {
    "layers": [],
    "folder_structure": {},
    "patterns": []
  },
  "conventions": {
    "naming": [],
    "anti_patterns": [],
    "file_structure": []
  }
}
```

> **Note:** `entities`, `routes`, and `contracts` are no longer stored here. They live in `nodes.json` and `edges.json` as part of the graph model (see graph memory design spec). `df-init` and `df-sync` write to the graph files exclusively for those categories.

`df-sync` patches this JSON directly. `memory.md` is regenerated from it (combined with the graph files) after every patch.

### config.json

```json
{
  "service": "ovell-core",
  "workspace": "ovell",
  "stack": "dotnet-9",
  "test_cmd": "dotnet test",
  "last_synced": "a3f9c12",
  "schema_version": 1,
  "node_types": {
    "custom": []
  },
  "edge_staleness_threshold": 30,
  "classifiers": {
    "entities":    ["**/Entities/*.cs", "**/Models/*.cs", "**/Domain/**/*.cs"],
    "routes":      ["*Controller.cs", "*Endpoint.cs", "**/pages/**/*.svelte", "**/routes/**/*.ts"],
    "contracts":   ["**/Contracts/**", "**/Events/**", "**/Messages/**"],
    "services":    ["**/Services/*.cs", "**/Handlers/*.cs"],
    "conventions": [".editorconfig", "*.globalconfig", ".eslintrc*", "*.prettierrc*"],
    "architecture":["Program.cs", "Startup.cs", "appsettings*.json", "vite.config.*"]
  }
}
```

> **Note:** `node_types` and `edge_staleness_threshold` are consumed by the graph pipeline (`df-sync`, `nodes.json`, `edges.json`). `conventions` and `architecture` classifiers update `memory.json` directly; all others classify into the graph.

---

## 5. df-sync — Hybrid Classification

`df-sync` runs on every hook invocation and after every skill completion. It diffs the current HEAD against `last_synced` and patches `memory.json`.

### Concurrency Lock

`df-sync` acquires a lockfile at `.devflow/sync.lock` using `flock` (non-blocking). If the lock is already held, the second invocation exits immediately with `[DevFlow] sync already running — skipping`. The lock is released on exit, including on SIGTERM. This prevents two simultaneous syncs (e.g. post-checkout hook + skill completion) from corrupting JSON files.

### Atomic Writes

All writes to `memory.json`, `nodes.json`, and `edges.json` use a temp-file + atomic rename pattern:

```
write → <file>.tmp
fsync <file>.tmp
rename <file>.tmp → <file>   # atomic on POSIX
```

A `"dirty": true` flag in `config.json` is set at the start of every sync run and cleared only after all files are written and renamed. Any skill that starts and finds `"dirty": true` re-runs `df-sync` before proceeding — it never reasons on a partial state.

### Failure Modes

| Failure | Behaviour |
|---|---|
| AI batch call times out | Retry once after 5s. If still failing: write nodes/edges without `intent`, set `confidence: "ai"`, log `[DevFlow] intent inference skipped — will retry on next sync`. Never block on intent. |
| Process killed mid-write | `dirty: true` survives in `config.json`. Next skill invocation detects it and re-runs `df-sync` from scratch against current HEAD. |
| Classifier glob throws | Skip the file, log a warning, continue. Never abort the entire sync for one unclassifiable file. |
| `flock` unavailable (e.g. NFS) | Fall back to a simple `.lock` file with PID check. If the PID no longer exists, remove the stale lockfile and proceed. |

### Classification Pipeline

```
for each changed file in diff:
  1. Match against config.json classifiers (glob patterns)
  2. If matched → classify into the matched section
  3. If unmatched → batch into AI classification call
  4. After AI classifies an unmatched file → append inferred pattern to config.json classifiers
```

**Heuristics** (step 1–2): fast, offline, deterministic. Handle 80%+ of changes on well-structured codebases.

**AI fallback** (step 3): unclassified files are batched into a single Claude call with the diff. Claude returns a classification + patch for `memory.json`. Never called per-file — always batched.

**Pattern learning** (step 4): AI-classified patterns are written back to `config.json` so subsequent syncs catch the same file type via heuristics. The classifier improves per-repo without manual tuning.

### Conflict Resolution

When two branches both modify the same section of `memory.json` (detected via merge-base diff):

1. The branch being switched to wins on its own section changes
2. Non-conflicting sections are merged automatically
3. Conflicting keys are flagged in a `memory_conflicts.json` file
4. The `feature` skill checks for `memory_conflicts.json` on startup and surfaces conflicts before proceeding

---

## 6. Branch Lifecycle

### Branch Name Canonicalization

Branch names are canonicalized to safe directory names before use as filesystem paths:

```
main                    → main
feature/comments        → feature__comments
234-add-payments        → 234-add-payments
fix/auth/token-expiry   → fix__auth__token-expiry
```

Rule: replace all `/` with `__`, preserve all other characters. `df-init` and `df-sync` always canonicalize before any filesystem operation.

### Switching Branches

`df-init` installs a `post-checkout` hook. Git passes a third argument to `post-checkout`: `1` for branch switch, `0` for file checkout. The hook exits immediately if `$3 != 1` — only branch switches trigger a sync.

On branch switch:

1. Hook fires `df-sync --branch-switch`
2. Canonicalize new branch name
3. Check if a memory directory exists for the canonicalized branch name
4. If yes — swap `active` symlink to that directory
5. If no — run `git merge-base` to get the divergence SHA, find which branch HEAD is closest to that SHA, copy its memory directory as a starting point, patch forward from the divergence SHA using `df-sync`
6. Update `last_synced` in `config.json` to the new HEAD SHA

### Stale Branch Cleanup

At the end of every `post-checkout` run, the script prunes stale memory:

```bash
# Canonicalize all local branch names, compare against branches/* directories
# Any directory with no matching local branch → rm -rf
git branch --list | sed 's|/|__|g' | ... compare against branches/*
```

### Degraded Mode

Every skill invocation starts by checking for `.devflow/active/memory.json`.

- If missing entirely: skill prints `[DevFlow] No memory found. Run /init to build memory for this repo. Proceeding without context — output quality will be reduced.` and continues with generic behavior.
- If `config.json` `"dirty": true`: a prior sync was interrupted. Skill re-runs `df-sync` before proceeding — never reasons on a partial state.
- If `last_synced` SHA diverges from HEAD: skill pauses, runs `df-sync`, then continues.
- If `memory_conflicts.json` exists: skill surfaces conflicts before any reasoning begins.

No silent degradation.

### Safety Net

Every skill invocation checks `last_synced` SHA against current HEAD. If they diverge (hook missed, manual copy, CI), the skill runs `df-sync` automatically before proceeding.

---

## 7. Workspace Registry

Multi-repo microservices are linked into a named workspace. Registry lives on the developer's machine.

```json
// ~/.devflow/workspaces/ovell.json
{
  "core":         "/path/to/OVELL.Core",
  "portal":       "/path/to/OVELL.Portal",
  "interactions": "/path/to/OVELL.Interactions",
  "jobs":         "/path/to/OVELL.Jobs",
  "media":        "/path/to/OVELL.Media"
}
```

`df-workspace read <workspace> <service> <memory-file>` returns a sibling service's `memory.md` as a string. This is the **only** cross-repo operation. Scripts must never write to a path outside the current repo's `.devflow/` directory — enforced by checking that the resolved path starts with `$PWD/.devflow/` before any write.

---

## 8. Feature Execution Flow

### Phase 1 — Domain Interrogation

Always runs before implementation. The `domain` skill asks expert questions about intent, constraints, and edge cases:

- *"Why does this need to exist — what user problem does it solve?"*
- *"What happens when the user is offline / unauthenticated / has no data?"*
- *"Is there existing code that covers 70% of this? Should we extend it or add new?"*
- *"Who else consumes this data — are there downstream services to notify?"*

Stops when enough context exists to make confident architectural decisions — typically 3–5 questions.

### Phase 2 — Slice Planning

AI reads `memory.md` and decomposes the feature into vertical slices. Each slice must:

- Span **all layers** it needs (not one layer per slice)
- Produce an **observable result** — something you can call, click, or assert on
- Have a declared **test command** that verifies that result
- Declare its **dependencies** on other slices — enabling parallel execution where possible

```json
// Written to .devflow/active/slices.json on user approval
{
  "feature": "comments",
  "approved_at": "2026-04-29T10:00:00Z",
  "slices": [
    {
      "id": 1,
      "name": "User can create a comment",
      "layers": ["db", "service", "api", "frontend"],
      "result": "POST /api/comments returns 201, comment visible in story view",
      "test_cmd": "playwright test --grep 'user can create a comment'",
      "depends_on": [],
      "status": "pending"
    },
    {
      "id": 2,
      "name": "User can delete a comment",
      "layers": ["service", "api", "frontend"],
      "result": "DELETE /api/comments/:id returns 204",
      "test_cmd": "playwright test --grep 'user can delete a comment'",
      "depends_on": [1],
      "status": "pending"
    },
    {
      "id": 3,
      "name": "User can list comments on a story",
      "layers": ["service", "api", "frontend"],
      "result": "GET /api/stories/:id/comments returns paginated list",
      "test_cmd": "playwright test --grep 'user can list comments'",
      "depends_on": [],
      "status": "pending"
    }
  ]
}
```

`slices.json` is written to disk on approval. It survives session restarts. `df-test` reads from it — it never receives a test command inline.

**Dependency rules enforced at planning time:**
- No circular dependencies — rejected with an explanation
- A `depends_on` entry may only reference slice IDs that exist in the same plan
- Two slices that touch the same file are automatically serialized — the skill infers this from `layers` and `df-explain` output and adds a `depends_on` entry even if the developer didn't specify one

A slice that only touches one layer is rejected — merged into an adjacent slice or split differently. The AI presents the slice plan and waits for explicit approval before executing slice 1.

The full parallel execution model — worktree lifecycle, agent dispatch, merge protocol — is specified in the parallel execution design spec.

### Phase 3 — Slice Execution Loop

Slices are executed in dependency order. Independent slices (no unsatisfied `depends_on`) form a "ready batch" and run in parallel via subagents in isolated git worktrees. Slices with dependencies wait until all their `depends_on` IDs reach `"done"`.

```
build DAG from depends_on fields → topological batches

for each batch:
  if 1 slice: execute inline (no worktree)
  if 2+ slices:
    check for file overlap via df-explain → serialize conflicts into next batch
    dispatch subagent per remaining slice in its own worktree
    wait for all to complete
    if any FAIL: cancel pending agents, surface findings, stop
    cherry-pick each worktree's commits onto branch (in slice-id order)
    remove worktrees
    run df-sync once for the batch
  update completed slice statuses to "done" in slices.json

No moving forward with a red slice. The loop is rigid on this.
```

### Phase 4 — Code Review

After all slices pass, the code-reviewer subagent fires automatically. It receives the full feature branch diff, `memory.md`, and `df-explain` output for every touched entity. It reviews against project conventions and flags inbound nodes affected but not touched by the PR.

Findings are severity-tagged: `blocking` halts the feature skill until resolved; `warning` and `note` are surfaced but do not block.

The full code-reviewer specification is in the parallel execution design spec.

### Phase 5 — Memory Sync

After all slices pass and no blocking review findings remain, `df-sync` diffs HEAD vs `last_synced`, runs the hybrid classifier, patches `memory.json`, regenerates `memory.md`, updates `config.json` with the new SHA, and deletes `slices.json`.

---

## 9. Fix Skill Flow

`/fix "comments endpoint returns 500 on empty body"`:

1. Read `memory.md` — understand routes and entities without codebase spelunking
2. Form a hypothesis before reading any code
3. Read only the files the hypothesis points to
4. Fix, run `df-test` if a slice exists, otherwise run `config.json` `test_cmd`
5. If wrong hypothesis: revise, repeat — max 3 cycles (one cycle = one hypothesis + reads + fix attempt)
6. If still failing after 3 cycles: surface findings and diagnosis — do not attempt a fourth cycle

---

## 10. Review Skill

`/review` reads `memory.md` (specifically architecture and conventions sections) before looking at any diff, then reads the full diff. Reviews against actual project conventions — not generic best practices. Flags:

- Calls that violate the service communication pattern (e.g., direct HTTP where async messaging is the convention)
- DI lifetime mismatches
- Naming deviations from `conventions.naming`
- Missing test coverage for a new vertical slice
- Cross-service contract changes without corresponding memory update
- Any file touched that has no classifier in `config.json` (triggers a prompt to run `df-sync`)

---

## 11. df-explain

`df-explain <file-or-symbol> [--depth N]`

> **Superseded by graph model.** The full interface is defined in the graph memory design spec. Summary:

1. Resolve input to a node in `nodes.json` — by node name (exact/fuzzy) or `file` field
2. BFS outbound edges (what this node depends on) and inbound edges (what depends on it) up to depth N (default: 1)
3. Flag any stale nodes in the result
4. Output a structured report showing the node, its relationships, and impact radius
5. If nothing resolves: print `[DevFlow] No memory found for "<input>". It may need a df-sync or a classifier entry.`

Diagnostic tool. Answers "is the memory aware of this file, and what does it affect?" without reading raw JSON.

---

## 12. df-export

`df-export [--output <path>]`:

Dumps current `memory.json` as a CLAUDE.md-compatible markdown block to stdout or a file. This is the escape hatch — lets a developer abandon `.devflow/` and maintain a flat file instead, or seed a team member's CLAUDE.md with a snapshot of current memory.

---

## 13. Installation

```bash
# Clone skill library
git clone https://github.com/<you>/devflow ~/.devflow

# Add scripts to PATH
echo 'export PATH="$HOME/.devflow/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Install skills into Claude Code (via CLAUDE.md or plugin directory)
# Add to your global ~/.claude/CLAUDE.md:
# Skills: ~/.devflow/skills/

# Initialize a repo (run inside the repo)
/init
```

`df-init` during `/init`:
1. Detects stack from project files
2. Scans architecture patterns
3. Generates `memory.json` with real content (not templates) using AI
4. Generates `memory.md` from `memory.json`
5. Creates `config.json` with current HEAD SHA, `schema_version: 1`, and inferred classifiers
6. Installs `post-checkout` hook
7. Prompts for workspace name and registers the repo
8. Creates `.gitignore` entry for `.devflow/`

---

## 14. What DevFlow Is Not

- Not a code generator — it reasons about architecture and asks expert questions
- Not a replacement for tests — it enforces tests per slice, it does not write tests instead of you
- Not a shared team tool — memory is local per developer by design
- Not opinionated about stack — it learns your stack from the codebase on init
- Not a human-readable wiki — `memory.json` is machine-first; `memory.md` is a render artifact, not a document
