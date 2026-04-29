# DevFlow — Design Spec
**Date:** 2026-04-29  
**Status:** Revised  
**Approach:** Option A — Skills + Shell Scripts

---

## 1. Vision

DevFlow is a Claude Code skill library that makes AI behave like a senior engineer — not an order-taker. It is stack-agnostic, general-purpose, and built around four principles:

1. **PRD first** — challenge and document intent before any planning or code
2. **Domain before implementation** — interrogate technical constraints and edge cases informed by the PRD
3. **Vertical slices** — every feature increment is a complete user-facing capability spanning all needed layers, tested and reviewed independently
4. **Accurate context** — AI maintains a machine-readable codebase model per developer, per branch, self-correcting as code evolves

---

## 2. Skills

| Skill | Trigger | Purpose |
|---|---|---|
| `init` | Once per repo | Scan codebase, build memory, register in workspace |
| `feature` | Main coding loop | PRD → domain interrogation → vertical slice DAG → per-slice agents → integration test → final review |
| `mem-sync` | After every commit | Diff-based memory update — patches `memory.json`, `nodes.json`, `edges.json`, regenerates `memory.md` |
| `fix` | Failing test or bug | Systematic debug using live memory context |
| `review` | Before merge | Architecture-aware code review against memory conventions |

> **Note:** `domain` is no longer a standalone skill. It is Phase 1 of the `feature` skill, informed by the approved PRD. Invoking `/domain` alone is unsupported — context without a plan is not actionable.

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
      prd.md           # approved PRD — kept until branch cleanup archives it
    feature-comments/
      memory.json
      memory.md
      slices.json
      prd.md
  prd-archive/         # permanent PRD record — survives branch deletion
    feature-comments_2026-04-29.md
    main_2026-04-15.md
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
  "edge_rel_types": {
    "builtin": ["depends_on", "uses", "persisted_in", "implements", "emits", "handles"],
    "custom": []
  },
  "graph_limits": {
    "max_nodes": 2000,
    "max_edges": 10000,
    "prune_min_age_commits": 90
  },
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

> **Note:** `node_types`, `edge_staleness_threshold`, `edge_rel_types`, and `graph_limits` are consumed by the graph pipeline (`df-sync`, `nodes.json`, `edges.json`). `edge_rel_types` is a closed set — any edge write with an unrecognised `rel` value is rejected with a warning. `graph_limits.prune_min_age_commits` controls the minimum age a stale node must reach before it is eligible for pruning when the graph exceeds `max_nodes`/`max_edges`. `conventions` and `architecture` classifiers update `memory.json` directly; all others classify into the graph.

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
git branch --list | sed 's|/|__|g' | ... compare against branches/*

# For each stale branch directory (no matching local branch):
#   1. Archive prd.md before deletion — permanent record
#   2. Then remove the branch directory
for STALE_DIR in branches/<stale-branch>/; do
  if [ -f "$STALE_DIR/prd.md" ]; then
    mkdir -p .devflow/prd-archive/
    ARCHIVE_NAME="${STALE_BRANCH}_$(date +%Y-%m-%d).md"
    cp "$STALE_DIR/prd.md" ".devflow/prd-archive/$ARCHIVE_NAME"
  fi
  rm -rf "$STALE_DIR"
done
```

`prd-archive/` is never pruned automatically. It is gitignored alongside the rest of `.devflow/`. `df-export` includes the full archive in its output when `--include-prd-archive` is passed.

### Degraded Mode

Every skill invocation starts by checking for `.devflow/active/memory.json`.

- If missing entirely: skill prints `[DevFlow] No memory found. Run /init to build memory for this repo. Proceeding without context — output quality will be reduced.` and continues with generic behavior.
- If `config.json` `"dirty": true`: a prior sync was interrupted. Skill re-runs `df-sync` before proceeding — never reasons on a partial state.
- If `last_synced` SHA diverges from HEAD: skill pauses, runs `df-sync`, then continues.
- If `memory_conflicts.json` exists: skill surfaces conflicts before any reasoning begins.
- If `graph_conflicts.json` exists: skill surfaces conflicted nodes and edges (with both `intent` values) before any reasoning begins. Skills must not reason on a node whose `intent` is contested. Developer resolves by accepting one value or writing a new one; `graph_conflicts.json` is deleted on resolution.

No silent degradation.

### Safety Net

Every skill invocation checks `last_synced` SHA against current HEAD. If they diverge (hook missed, manual copy, CI), the skill runs `df-sync` automatically before proceeding.

### CI/CD environments

CI environments have no `.devflow/` directory and never run `df-init`. Skills and scripts handle this gracefully rather than failing:

- All `df-*` scripts check for the existence of `.devflow/` at startup. If absent, they print `[DevFlow] No .devflow/ directory found — running in CI mode. Exiting 0.` and exit with code 0. They never fail a CI build due to missing memory.
- `df-test` is the one exception: it checks for `DEVFLOW_TEST_CMD` environment variable first. If set, it runs that command instead of reading `slices.json`. If neither `DEVFLOW_TEST_CMD` nor `.devflow/` is present, it prints `[DevFlow] No test command found. Set DEVFLOW_TEST_CMD or run df-init.` and exits 1.
- `df-sync`, `df-explain`, and `df-export` exit 0 silently in CI (no `.devflow/`). They are developer-workstation tools.
- The `review` skill in CI receives no `memory.md` — it performs a generic diff review with a warning: `[DevFlow] No memory found — review is not architecture-aware.`

DevFlow is a developer-workstation tool. CI is a supported runtime only for `df-test`. All other scripts and skills degrade to silent no-ops in CI rather than blocking the build.

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

### Phase 0 — PRD

Always the first phase. The feature skill interrogates the developer with critical, direct questions — one at a time — until it has enough context to draft a complete PRD. The AI does not accept vague answers and does not move on until ambiguity is resolved.

**Interrogation style:** the AI is sceptical by default. It challenges assumptions, surfaces contradictions, and asks "why" repeatedly. It does not validate the developer's idea — it stress-tests it. A question is not closed until the answer is specific enough to write a testable acceptance criterion.

**Suggested answers:** every question includes 2–3 best-practice suggestions derived from the stack, the memory graph, and the domain. The developer picks one, combines them, or overrides with their own answer. Suggestions are never the default — the developer must make an explicit choice.

**Questions cover:**

| Area | Example question with suggestions |
|---|---|
| Problem | "What breaks or can't be done today without this? [A] User has no way to respond to stories. [B] Moderation team can't manage user-generated content. [C] Something else." |
| User | "Who is the primary actor? [A] Authenticated end user. [B] Admin/moderator. [C] External API consumer." |
| Success | "How do we know this is done? [A] User can create and see a comment without a page reload. [B] E2E test passes for create/read/delete flow. [C] Something else." |
| Failure states | "What should happen when the user submits an empty comment? [A] Client-side validation blocks submission. [B] API returns 422 with field error. [C] Silent discard." |
| Out of scope | "Should comment editing be in scope? [A] No — read-only after submit. [B] Yes, within 5 minutes. [C] Out of scope for now, separate feature." |
| Constraints | "Any systems this must integrate with that aren't in memory? [A] No. [B] Yes — specify." |

The AI stops asking when all six areas have specific, unambiguous answers — typically 5–9 questions total.

**PRD structure written to `.devflow/active/prd.md` on approval:**

```markdown
# PRD — <feature name>
**Branch:** feature/comments
**Date:** 2026-04-29
**Status:** Approved

## Problem
One paragraph. The user problem, not the technical solution.

## User
Who this is for and what they can do that they couldn't before.

## Success Criteria
Numbered list. Each item is observable and maps to a slice result.

## Out of Scope
Explicit exclusions. Anything not listed is in scope.

## Edge Cases & Failure States
Bulleted list. Each maps to a test case in the slice plan.

## Constraints
Deadlines, dependencies, systems to integrate with, things that cannot change.
```

No slice planning starts until the developer types an explicit approval. `prd.md` is kept after the feature completes — it is a permanent record of what was built and why.

---

### Phase 1 — Domain Interrogation

Runs after PRD approval. Shorter than before — the PRD already captured intent and constraints. This phase focuses on **technical decisions** the PRD doesn't answer.

**Cross-workspace context loading:** Before asking domain questions, the `feature` skill checks `config.json` for a `workspace` name. If one exists, it scans the approved `prd.md` for any mentions of sibling service names registered in the workspace. For each named sibling service, it runs:

```bash
df-workspace read <workspace> <service> memory.md
```

The returned `memory.md` is injected into the domain interrogation context alongside the local `memory.md`. This gives the AI cross-service graph context — contracts, routes, entities — without requiring the developer to describe sibling APIs manually.

If the PRD mentions no sibling services, cross-workspace loading is skipped entirely. It is never automatic for all services in the workspace — only for services explicitly referenced in the approved PRD.

The AI reads `memory.md` (and any loaded sibling `memory.md` files) and asks targeted questions about implementation approach, using the same style as Phase 0: one question at a time, critical and direct, with best-practice suggestions on every question.

Typical questions:

- *"The PRD says comments are soft-deletable. The graph shows User is hard-deleted after 90 days. What should happen to comments when the author is deleted? [A] Orphan the comment, show '[deleted]'. [B] Cascade-delete all comments. [C] Anonymise comment body."*
- *"Is there existing code that covers 70% of this? [A] Yes — CommentService in memory. [B] No — greenfield. [C] Partial — needs extension."*
- *"Who else consumes comment data downstream? [A] FeedService (already in graph). [B] NotificationService (not in graph — add to constraints). [C] Nobody."*

Stops when enough context exists to make confident architectural decisions — typically 3–5 questions.

### Phase 2 — Slice Planning

AI reads `prd.md` and `memory.md` and decomposes the feature into vertical slices.

#### Vertical Slice Definition

A vertical slice is a **complete user-facing capability** — not a layer, not a technical task. It:

1. Implements **one thing a user can do** — described in plain language ("User can create a comment")
2. Spans **every layer it needs** to deliver that capability — never stops at a layer boundary
3. Produces a **user-observable result** that maps to a PRD success criterion
4. Is **independently testable** without other slices being implemented first

**Rejected slice forms (enforced at planning time):**

| Form | Rejection reason |
|---|---|
| "Add Comment table migration" | Layer-only — no user outcome |
| "Implement CommentService CRUD" | Layer-only — split into Create / Read / Update / Delete |
| "Add frontend comment form" | Layer-only — belongs inside the Create slice |
| "Refactor service layer" | No user outcome — done inline within whichever slice needs it |

A slice that touches only one layer is **always rejected**. The AI merges it into the adjacent slice or re-plans.

**CRUD decomposition pattern:**

For a Comments feature, the correct slice plan is:

| Slice | Capability | Layers | Maps to PRD criterion |
|---|---|---|---|
| 1 | User can create a comment | db, entity, service, API, frontend | "User can submit a comment" |
| 2 | User can read comments on a story | service, API, frontend | "Comments appear below the story" |
| 3 | User can edit their comment | service, API, frontend | "User can correct a submitted comment" |
| 4 | User can delete their comment | service, API, frontend | "User can remove their own comment" |

Each slice must:

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

The full parallel execution model — worktree lifecycle, agent dispatch, per-slice test and review agents, and final agents — is specified in the parallel execution design spec.

### Phase 3 — Slice Execution

Slices execute in dependency order. Each slice runs through three dedicated agents in sequence, each with a clean, scoped context (target: under 50k tokens):

```
for each batch (topological order from depends_on DAG):
  if 1 slice: run agents inline (no worktree)
  if 2+ slices: dispatch per worktree, run agents inside each worktree

  per slice:
    → Implementation Agent   (slice def + memory.md + df-explain output)
    → Test Agent             (slice def + slice diff only — clean context, gated)
    → Slice Review Agent     (slice diff + memory.md conventions + df-explain — gated on green)

  on any agent failure: surface findings, halt — do not advance
  merge batch commits, df-sync once per batch
```

No moving forward with a red slice. The loop is rigid on this.

### Phase 4 — Integration Test

After all slices reach `"done"`, a dedicated Integration Test Agent fires with a clean context. It runs every slice's `test_cmd` in sequence and writes one end-to-end test that exercises the full feature flow (e.g. create → read → edit → delete). Its job is to verify that slices compose correctly — not that each works in isolation (that was the per-slice test agent's job).

On failure: surfaces which cross-slice interaction broke. Escalates to developer — does not attempt to fix.

### Phase 5 — Final Review

A dedicated Final Review Agent fires after integration tests pass. It focuses exclusively on cross-slice concerns — per-slice conventions were already reviewed in Phase 3:

- Cross-slice contract consistency (error shapes, API conventions across Create/Read/Update/Delete)
- Emergent patterns only visible across the full diff
- Graph drift — entities touched across multiple slices with conflicting intent
- Full impact radius — inbound nodes affected by the combined diff

Findings use the same `blocking` / `warning` / `note` severity model. `blocking` halts until resolved, then the Final Review Agent re-runs on the updated diff.

### Phase 6 — Memory Sync

After all slices pass, integration tests pass, and no blocking review findings remain: `df-sync` runs its final pass, `slices.json` is deleted. `prd.md` is kept as a permanent record.

---

## 9. Fix Skill Flow

`/fix "comments endpoint returns 500 on empty body"`:

1. Run `df-explain` on the failing endpoint or entity — use the inbound edge list to identify all connected nodes before reading any code
2. Read `memory.md` — understand the broader context (architecture, conventions) without codebase spelunking
3. Form a hypothesis before reading any code
4. Read only the files the hypothesis and `df-explain` output point to
5. Fix, then determine the test command:
   - If `.devflow/active/slices.json` exists **and** the `feature` field in `slices.json` matches the current branch name **and** `integration_status` is not `"pass"`: run `df-test <slice-id>` for the slice most likely affected by the fix.
   - Otherwise: run the `test_cmd` from `config.json`. A `slices.json` from a prior completed or abandoned feature must not be used — it may reference a stale test command for a deleted test.
6. If wrong hypothesis: revise, repeat — max 3 cycles (one cycle = one hypothesis + reads + fix attempt)
7. If still failing after 3 cycles: surface findings and diagnosis — do not attempt a fourth cycle

---

## 10. Review Skill

**Pre-review checks:** Before reading `memory.md` or the diff, `/review` checks for:

- `graph_conflicts.json` — if present, surfaces all conflicted nodes and their contested `intent` values. The review proceeds but marks any finding that touches a conflicted node with a `[contested-intent]` tag, since the conventions being checked may themselves be unresolved. The developer should run `df-resolve` before relying on review output for affected nodes.
- `config.json` `"dirty": true` — re-runs `df-sync` before proceeding.
- `last_synced` SHA divergence from HEAD — re-runs `df-sync` before proceeding.

`/review` reads `memory.md` (specifically architecture and conventions sections) before looking at any diff, then reads the full diff, then runs `df-explain` on every changed node. Reviews against actual project conventions — not generic best practices. Flags:

- Calls that violate the service communication pattern (e.g., direct HTTP where async messaging is the convention)
- DI lifetime mismatches
- Naming deviations from `conventions.naming`
- Missing test coverage for a new vertical slice
- Cross-service contract changes without corresponding memory update
- Any file touched that has no classifier in `config.json` (triggers a prompt to run `df-sync`)
- Inbound nodes that weren't touched by the PR but whose behaviour may have changed (surfaced from `df-explain` output)

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
4. Scans classifiers, builds initial `nodes.json` and `edges.json` using static analysis for structure + AI (batched) for intent
5. Generates `memory.md` from `memory.json` + `nodes.json` + `edges.json`
6. Creates `config.json` with current HEAD SHA, `schema_version: 1`, and inferred classifiers
7. Installs `post-checkout` hook — swaps `active` symlink on branch switch and triggers `df-sync --branch-switch`
8. Installs `post-commit` hook — invokes `mem-sync` after every commit to keep memory current with HEAD
9. Prompts for workspace name and registers the repo
10. Creates `.gitignore` entry for `.devflow/`

### Re-initialization

If `.devflow/` already exists when `/init` is invoked, `df-init` runs in **update mode**:

1. Reads `config.json` to confirm the repo and schema version.
2. If `schema_version` in `config.json` is lower than the current binary's schema version: runs the migration path before proceeding (see graph memory design spec §11).
3. Re-runs steps 1–6 of the init flow above, patching `config.json`, `memory.json`, `nodes.json`, and `edges.json` incrementally — it does **not** reset them to empty.
4. Re-installs both hooks (idempotent — safe to run if hooks were removed or corrupted).
5. Does **not** prompt for workspace name again — the existing workspace registration is preserved.
6. Prints `[DevFlow] Re-initialized. Memory patched from <old-sha> to <HEAD-sha>.`

**When to re-init:**
- After a major stack change (new framework added, language version bumped)
- After cloning a repo where `.devflow/` was deleted (e.g. by `git clean -fdx`)
- After a schema version upgrade

**What it never does in update mode:** wipe existing `intent` strings or reset `nodes.json`/`edges.json` content. Re-init patches forward — it does not rebuild from scratch unless `--reset` is passed explicitly.

`df-init --reset` wipes `.devflow/branches/<current-branch>/` and rebuilds from scratch. It does not touch `prd-archive/` or other branch directories.

---

## 14. What DevFlow Is Not

- Not a code generator — it reasons about architecture and asks expert questions
- Not a replacement for tests — it enforces tests per slice, it does not write tests instead of you
- Not a shared team tool — memory is local per developer by design
- Not opinionated about stack — it learns your stack from the codebase on init
- Not a human-readable wiki — `memory.json` is machine-first; `memory.md` is a render artifact, not a document
