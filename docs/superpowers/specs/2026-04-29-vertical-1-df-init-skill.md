# Vertical 1 — `df-init` + `init` skill
**Date:** 2026-04-29  
**Status:** Approved  
**Approach:** Option B — Skill-heavy, script-thin  
**Depends on:** `InitialSpec.md` v2.0, `2026-04-29-graph-memory-design.md`

---

## 1. What This Vertical Delivers

A developer can run `/init` in any git repo and end up with a fully initialized `.devflow/` directory. The `init` skill drives the interactive conversation; `df-init` handles all mechanical file operations. No AI reasoning lives in the script.

**Success criteria:**

1. Running `/init` in a fresh repo creates all required `.devflow/` files and installs git hooks.
2. Running `/init` in a repo with an existing `.devflow/` patches forward without wiping `intent` strings.
3. Running `df-init --reset` wipes only the current branch and rebuilds from scratch.
4. `DEVFLOW_AI_MOCK=1` runs the full flow end-to-end without real API calls.
5. All `tests/df-init.bats` test categories pass.
6. The flow works on any git repo — not just Ovell.

---

## 2. File Layout After Init

```
<repo-root>/
  .devflow/
    config.json                        # stack, classifiers, graph config
    active -> branches/<branch>/       # symlink, points to current branch
    branches/
      <canonicalized-branch>/
        memory.json                    # stack, architecture, conventions
        memory.md                      # auto-generated render — skills read this
        nodes.json                     # classified entities, routes, services, contracts
        edges.json                     # inferred relationships
    snapshots/                         # created by df-export --snapshot (not df-init)
    prd-archive/                       # PRD records (not df-init)
  .git/
    hooks/
      post-commit                      # calls df-sync
      post-checkout                    # swaps active symlink + calls df-sync --branch-switch
```

`.devflow/` is gitignored. Scripts write only inside `$PWD/.devflow/` — this is enforced by checking the resolved write path before any file operation.

---

## 3. `df-init` Script

### Location

`~/.devflow/bin/df-init`

### Responsibility

All mechanical, deterministic operations. No AI. No interactive prompts (those belong to the skill).

### Interface

```bash
df-init --version              # print DevFlow version string and exit 0
df-init --scan                 # scan repo, output classification manifest JSON to stdout, exit 0
df-init --write-memory         # read memory patch JSON from stdin, write all files atomically, exit 0|1
df-init --reset                # wipe current branch memory, rebuild from scratch (requires --write-memory pass)
df-init --undo-classifier "<pattern>"  # remove a learned classifier pattern from config.json
```

`--scan` and `--write-memory` are the two halves of the init protocol. The skill calls `--scan`, does the AI reasoning, then calls `--write-memory` with results.

### Step-by-step flow

**Mode: fresh init (no `.devflow/` exists)**

1. **Validate prerequisites**
   - `git` ≥ 2.20 (`git --version`)
   - `jq` ≥ 1.6 (`jq --version`)
   - `flock` available — if not, fall back to PID-based `.lock` file
   - Must be run inside a git repo (`git rev-parse --is-inside-work-tree`)
   - On failure: print specific error, exit 1

2. **`--scan` mode**
   - Run `git ls-files` to enumerate all tracked files
   - Apply classifiers from `DEFAULT_CLASSIFIERS` (built-in fallback, used before `config.json` exists):
     ```
     entities:     **/Entities/*.cs, **/Models/*.cs, **/Domain/**/*.cs
     routes:       *Controller.cs, *Endpoint.cs, **/pages/**/*.svelte, **/routes/**/*.ts
     contracts:    **/Contracts/**, **/Events/**, **/Messages/**
     services:     **/Services/*.cs, **/Handlers/*.cs
     conventions:  .editorconfig, *.globalconfig, .eslintrc*, *.prettierrc*
     architecture: Program.cs, Startup.cs, appsettings*.json, vite.config.*
     ```
   - Output to stdout as JSON:
     ```json
     {
       "schema_version": 1,
       "head_sha": "<current HEAD sha>",
       "branch": "<current branch name>",
       "branch_canonicalized": "<canonicalized branch name>",
       "classified": [
         { "file": "Entities/Comment.cs", "type": "entity", "confidence": "high" }
       ],
       "unclassified": [
         { "file": "src/lib/utils/slug.ts" }
       ],
       "stack_hints": {
         "files_found": ["Program.cs", "vite.config.ts", "package.json"],
         "inferred": { "runtime": "dotnet-9", "frontend": "sveltekit" }
       }
     }
     ```
   - Exit 0

3. **`--write-memory` mode**
   - Read memory patch JSON from stdin. Expected shape:
     ```json
     {
       "config": { ... },           // full config.json content
       "memory": { ... },           // full memory.json content
       "nodes": { "schema_version": 1, "nodes": [...] },
       "edges": { "schema_version": 1, "edges": [...] }
     }
     ```
   - Set `config.json` `"dirty": true` before any file write
   - Create `.devflow/` and branch directory with `mkdir -p`
   - Write all four files using atomic write pattern:
     ```
     write → <file>.tmp  →  fsync  →  rename <file>.tmp → <file>
     ```
   - Regenerate `memory.md` from `memory.json` + `nodes.json` + `edges.json` (render format: see graph memory design spec §6)
   - Create `active` symlink: `ln -sfn branches/<branch-canonicalized> .devflow/active`
   - Validate all writes succeeded (check file exists, is valid JSON)
   - Clear `"dirty": false` in `config.json`
   - Exit 0 on success, exit 1 on any write failure (print specific error)

4. **Install git hooks** (runs after `--write-memory` succeeds)
   - Write `post-commit` hook:
     ```bash
     #!/bin/bash
     df-sync
     ```
   - Write `post-checkout` hook:
     ```bash
     #!/bin/bash
     # $3 == 1 means branch switch; $3 == 0 means file checkout
     [ "$3" = "1" ] || exit 0
     df-sync --branch-switch
     ```
   - Both hooks are idempotent — if a hook already exists with the DevFlow header `# DevFlow managed`, overwrite it. If it exists without the header, append the call rather than overwriting (preserves existing hook logic).
   - `chmod +x` both hooks

**Mode: re-init (`.devflow/` exists, no `--reset`)**

1. Read `config.json` — confirm `schema_version`. Run migration if lower than expected binary version.
2. Re-run `--scan` from current HEAD.
3. Skill re-runs AI pass for any unclassified files or nodes with cleared `intent`.
4. `--write-memory` patches incrementally — never wipes existing `intent` strings. Node IDs that exist in `nodes.json` with `confidence: "manual"` are never overwritten.
5. Re-install hooks (idempotent).
6. Print `[DevFlow] Re-initialized. Memory patched from <old-sha> to <HEAD-sha>.`

**Mode: `--reset` (wipe current branch)**

1. Take a snapshot first: copy current branch's files to `.devflow/snapshots/<timestamp>/`
2. Delete `.devflow/branches/<current-branch>/`
3. Fall through to fresh init flow (but `.devflow/` directory itself remains — only the branch directory is wiped)
4. Print `[DevFlow] Reset complete. Memory rebuilt from scratch for branch <branch>.`

### Branch name canonicalization

```
main                    → main
feature/comments        → feature__comments
234-add-payments        → 234-add-payments
fix/auth/token-expiry   → fix__auth__token-expiry
```

Rule: replace all `/` with `__`. Applied before any filesystem path construction.

### Concurrency and atomicity

- Acquires `.devflow/sync.lock` via `flock` (non-blocking) before any write. Falls back to PID-based lock if `flock` unavailable.
- All file writes use temp-file + fsync + atomic rename.
- `"dirty": true` set at start of write phase, cleared only after all files written and verified.

### Error handling

| Failure | Behaviour |
|---|---|
| Not in a git repo | Print `[DevFlow] Not a git repo. Run df-init inside a git repository.` Exit 1. |
| Missing prerequisite | Print specific missing tool name and minimum version. Exit 1. |
| Write failure on any file | Print `[DevFlow] Write failed: <file>. Check disk space and permissions.` Leave `dirty: true`. Exit 1. |
| Invalid JSON from stdin | Print `[DevFlow] Invalid memory patch JSON. Aborting write.` Exit 1. |
| Schema version mismatch | Run migration before proceeding (see graph memory spec §11). |

### CI mode

If `.devflow/` does not exist, all `df-*` scripts (including `df-init`) print `[DevFlow] No .devflow/ directory found — running in CI mode. Exiting 0.` and exit 0. Exception: `df-init` itself — when called explicitly, it always runs (it is the tool that creates `.devflow/`). The CI guard applies to other scripts only.

---

## 4. `init` Skill

### Location

`~/.devflow/skills/init/SKILL.md`

### Format

Single `SKILL.md` file. Follows the superpowers skill format (same as skills in `~/.config/opencode/skills/`). Invoked as `/init` in Claude Code.

### Flow

```
1. Run df-init --scan → parse classification manifest JSON
2. Present detected stack to developer (confirm or correct)
3. Ask: workspace name? (optional — skip if solo repo)
4. Ask: any custom node types to add? (optional)
5. Ask: any custom classifiers to add? (optional)
6. Batch-call Claude API for:
   a. Intent inference on all classified nodes
   b. Classification + intent for unclassified files
   c. Edge inference (static analysis supplemented by AI for ambiguous relationships)
7. Assemble memory patch JSON
8. Run df-init --write-memory < memory-patch.json
9. Print verification checklist
```

### Interactive questions (one at a time)

**Question 1 — Stack confirmation**

Show the `stack_hints` from `--scan` output:
```
[DevFlow] I found the following stack in this repo:
  Runtime:  dotnet-9 (found Program.cs, *.csproj)
  Frontend: sveltekit (found vite.config.ts, src/routes/)
  Test cmd: (not detected — I'll ask)

Is this correct? [Y] Yes / [N] No, let me correct it
```
If N: ask for the correct values one at a time (runtime, frontend, test_cmd).

**Question 2 — Workspace**

```
[DevFlow] Is this repo part of a multi-service workspace?
  [A] Yes — I'll give it a name
  [B] No — standalone repo
```
If A: ask for workspace name (e.g. "ovell"), register in `~/.devflow/workspaces/<name>.json`.

**Question 3 — Custom node types** (only if the scan found files that don't match any built-in type)

```
[DevFlow] I found <N> files I couldn't classify. Would you like to define custom node types for them?
  [A] Yes — show me the files
  [B] No — treat them as untyped / let AI classify
```

**Question 4 — Review unclassified files** (only if A chosen above)

Show files in batches of 10. Developer assigns type or skips.

### Claude API calls

All AI work is done in the skill, not the script.

**Call 1 — Batch intent + classification**

Single call. Prompt includes:
- All classified files with their type and file content summary (first 50 lines or full file if < 50 lines)
- All unclassified files with their content
- Stack context from manifest

Returns per-file:
```json
[
  {
    "file": "Entities/Comment.cs",
    "type": "entity",
    "confidence": "ai",
    "intent": "Soft-deletable content unit attached to a story",
    "edges": [
      { "to_file": "Entities/User.cs", "rel": "depends_on", "intent": "author ownership" }
    ]
  }
]
```

**Retry on timeout:** retry once after 5 seconds. If still failing: write nodes without `intent`, set `confidence: "ai"`, log `[DevFlow] intent inference skipped — will retry on next df-sync`.

**Call 2 — Edge inference for architecture files**

Separate call for `architecture` and `conventions` classifier files — these write to `memory.json` (stack, architecture, conventions sections), not to the graph. Returns a patch for `memory.json`.

### Memory patch JSON assembled by skill

```json
{
  "config": {
    "service": "<repo-dir-name>",
    "workspace": "<workspace-name or null>",
    "stack": "dotnet-9",
    "test_cmd": "dotnet test",
    "last_synced": "<HEAD-sha>",
    "schema_version": 1,
    "node_types": { "custom": [] },
    "edge_staleness_threshold": 30,
    "edge_rel_types": {
      "builtin": ["depends_on", "uses", "persisted_in", "implements", "emits", "handles"],
      "custom": []
    },
    "graph_limits": { "max_nodes": 2000, "max_edges": 10000, "prune_min_age_commits": 90 },
    "classifiers": { ... }
  },
  "memory": {
    "schema_version": 1,
    "last_synced": "<HEAD-sha>",
    "stack": { "runtime": "dotnet-9", "frontend": "sveltekit", "test_cmd": "dotnet test", "key_dependencies": [] },
    "architecture": { "layers": [], "folder_structure": {}, "patterns": [] },
    "conventions": { "naming": [], "anti_patterns": [], "file_structure": [] }
  },
  "nodes": {
    "schema_version": 1,
    "nodes": [ ... ]
  },
  "edges": {
    "schema_version": 1,
    "edges": [ ... ]
  }
}
```

### Verification checklist (printed after write)

```
[DevFlow] Initialization complete.

  ✓ .devflow/config.json written
  ✓ .devflow/branches/<branch>/memory.json written
  ✓ .devflow/branches/<branch>/nodes.json written (<N> nodes)
  ✓ .devflow/branches/<branch>/edges.json written (<N> edges)
  ✓ .devflow/branches/<branch>/memory.md generated
  ✓ .devflow/active symlink → branches/<branch>/
  ✓ .git/hooks/post-commit installed
  ✓ .git/hooks/post-checkout installed

To verify: type /init in Claude Code — skill should activate.
Run df-explain <any entity name> to test memory lookup.
```

---

## 5. Tests

### File

`tests/df-init.bats`

### Test categories

| Category | What it tests |
|---|---|
| Fresh init | All required files created; `active` symlink correct; hooks installed; `dirty` cleared |
| Re-init | Patches without wiping; manual `confidence` nodes not overwritten; SHA updated |
| `--reset` | Wipes current branch dir; snapshot created in `snapshots/`; other branches untouched |
| Hook idempotency | Running `--write-memory` twice doesn't duplicate hook calls; existing non-DevFlow hooks preserved |
| `--scan` output | Valid JSON; classified/unclassified split correct; `stack_hints` populated |
| CI mode | Other df-* scripts exit 0 when no `.devflow/` exists |
| AI mock | `DEVFLOW_AI_MOCK=1` reads from `tests/fixtures/ai-responses/df-init-response.json`; no real API call |
| Error paths | Not-a-git-repo → exit 1; invalid JSON stdin → exit 1; write failure → dirty flag survives |
| Canonicalization | Branch names with `/` are correctly canonicalized to `__` |

### Fixture files

```
tests/
  fixtures/
    sample-repo/          # minimal git repo with known file structure
    ai-responses/
      df-init-response.json   # canned AI response for DEVFLOW_AI_MOCK=1
```

### Running

```bash
bats tests/df-init.bats        # this vertical only
bats tests/                    # all tests (later verticals will add files here)
```

---

## 6. Definition of Done

- [ ] `df-init` script exists at `~/.devflow/bin/df-init` (or `bin/df-init` in the repo)
- [ ] `init` skill exists at `skills/init/SKILL.md`
- [ ] All `tests/df-init.bats` categories pass
- [ ] End-to-end: `/init` works in the Ovell repo and produces a valid `.devflow/` directory
- [ ] End-to-end: `/init` works in a second, unrelated repo (confirms stack-agnostic)
- [ ] `DEVFLOW_AI_MOCK=1` flow passes without real API calls
- [ ] `shellcheck bin/df-init` passes with no errors

---

## 7. Out of Scope for This Vertical

- `df-sync` and `mem-sync` skill (Vertical 2)
- `df-explain` (Vertical 3)
- `feature` skill (Vertical 4)
- `fix` skill (Vertical 5)
- `review` skill (Vertical 6)
- `df-workspace`, `df-export`, `df-resolve` (bundled into relevant later verticals)
- Parallel execution (Vertical 4+)
