---
name: devflow-init
description: Use when initializing DevFlow memory for a new repository or re-classifying files after structural changes
requires: []
triggers_on_complete: [verify]
---

# Skill: init

# DevFlow Init

Initialize DevFlow memory for the current repository. Performs automated stack detection, AI-powered node/edge classification, and atomic memory write with a single user gate before writing.

**When invoked:** `/init` in Claude Code while inside any git repo.

**Prerequisite:** `df-init` must be on PATH. Install DevFlow first if needed.

---

## The Iron Law

```
NEVER OVERWRITE EXISTING MEMORY WITHOUT EXPLICIT USER CONSENT.
One gate. Final. Then write.
```

---

## Autonomy Tiers

See `skills/_shared.md` for full T1/T2/T3 definitions.

| Operation | Tier | Behavior |
|-----------|------|----------|
| Stack detection | T1 | Silent — auto-detect from filesystem |
| Workspace name derivation | T1 | Silent — from git remote or directory name |
| File classification (unambiguous types) | T1 | Silent — expanded auto-classifier |
| Print detection results | T2 | Inform, no wait |
| Final summary before write | T3 | Gate — present and wait |

---

## Auto-classifier Table (T1 Silent)

| Pattern | Node Type |
|---------|-----------|
| `*.test.*, *.spec.*, __tests__/**` | test |
| `*.config.*, *.env*, .eslintrc*, tsconfig*, vite.config*, jest.config*` | config |
| `*.md, *.mdx, docs/**` | docs |
| `Dockerfile, docker-compose*, .github/**/*.yml, .github/**/*.yaml` | infra |
| `*.sql, migrations/**, **/migrations/**` | data |
| `package.json, *.lock, go.mod, requirements.txt, go.sum, Cargo.toml, Gemfile, pyproject.toml` | deps |
| `bin/**, scripts/**, Makefile, *.sh, Taskfile*` | script |
| Everything else | source |

---

## Stack Detection Rules (T1 Silent)

| Signal | Inferred |
|--------|----------|
| `package.json` present | runtime: nodejs |
| `package.json` + `vite.config.*` | frontend: sveltekit |
| `package.json` + `next.config.*` | frontend: nextjs |
| `*.csproj` or `*.sln` | runtime: dotnet-9 |
| `requirements.txt` or `pyproject.toml` | runtime: python |
| `go.mod` | runtime: go |
| `Cargo.toml` | runtime: rust |
| `Gemfile` | runtime: ruby |
| `git remote get-url origin` | workspace name (strip host/org, use repo name) |
| No remote | workspace name = `basename` of git root directory |

---

## Flow

### Step 1 — Scan the repo (T1)

Verify `df-init` is on PATH:

```bash
which df-init
```

If not found: HALT. Print exactly: "DevFlow not initialized — install DevFlow and add `~/.devflow/bin` to your PATH."

Run:

```bash
df-init --scan
```

Parse JSON output. Extract: `stack_hints`, `classified`, `unclassified`, `branch`, `branch_canonicalized`, `head_sha`.

If the command fails:
- "Not a git repo" → HALT. Print: "Run `/init` inside a git repository."
- "Missing prerequisite" → HALT. Show missing tool name.
- Any other error → HALT. Show raw error.

### Step 2 — T1: Auto-detect everything silently

Apply the stack detection rules and auto-classifier table above. No prompts. Log all T1 decisions to session audit list.

### Step 3 — T2: Report what was detected

Print (do not wait):
```
[DevFlow] Detected: <runtime> + <frontend>. Workspace: <derived-name>.
[DevFlow] Classified <N> files automatically (0 unclassified).
```

Continue immediately.

### Step 4 — T3: Final summary gate (the ONLY gate)

Present before writing memory:

```
[DevFlow] Ready to initialize. Here's what I'll write:

  Workspace:  <name>
  Runtime:    <runtime>
  Frontend:   <frontend>
  Test cmd:   <test_cmd or "not detected — will use df-sync">
  Nodes:      <N> (all auto-classified)
  Branch:     <branch>

  Auto-classified (T1 Silent):
    <count> source, <count> test, <count> config,
    <count> docs, <count> infra, <count> data,
    <count> deps, <count> script

  Proceed? [Y / tell me what to change]
```

If user says Y: proceed to Step 5.
If user requests changes: apply changes and re-present this summary. Do not re-run df-init --scan unless specifically needed.

### Step 5 — AI: intent + classification + edges

**DEVFLOW_AI_MOCK=1 mode:** If `DEVFLOW_AI_MOCK` environment variable equals `1`, read from `~/.devflow/tests/fixtures/ai-responses/df-init-response.json`. Use `call1` in place of real Call 1 response and `call2` in place of real Call 2 response.

**Real mode:**

Make a single Claude API batch call with:
- All classified files + their type + first 50 lines of file content (or full file if < 50 lines)
- Stack context from scan manifest

Prompt:

````
You are analyzing a codebase to initialize DevFlow memory.

For each file below, return a JSON array where each entry has:
- "file": the relative file path
- "type": one of: entity, service, route, contract, or a custom type if specified
- "confidence": "ai"
- "intent": one sentence — the *why* behind this file's existence (what business purpose it serves, not what it does technically)
- "edges": array of { "to_file": "<relative-path>", "rel": "<rel-type>", "intent": "<why>" }
  where rel is one of: depends_on, uses, persisted_in, implements, emits, handles

Stack context: <stack_runtime> + <stack_frontend>

Files:
<file-list with content>

Return only the JSON array. No explanation.
````

On timeout: wait 5 seconds, retry once. On second failure: write nodes without `intent`, set `confidence: "ai"`, log T2: `[DevFlow] intent inference skipped — will retry on next df-sync`.

**Call 2 — Architecture/conventions for memory.json:**

Second call using `stack_hints.files_found` files. Pass their full content:

````
Based on these files from a <stack_runtime> + <stack_frontend> project, infer:

1. Architecture layers (e.g. ["api", "services", "entities", "frontend"])
2. Folder structure description (object: folder → one-line purpose)
3. Patterns in use (e.g. ["vertical slices", "event-driven", "clean architecture"])
4. Naming conventions (list of observed conventions)
5. Anti-patterns to avoid (if any are obvious from the code)

Return JSON:
{
  "stack": { "runtime": "...", "frontend": "...", "test_cmd": "...", "key_dependencies": [] },
  "architecture": { "layers": [], "folder_structure": {}, "patterns": [] },
  "conventions": { "naming": [], "anti_patterns": [], "file_structure": [] }
}
````

### Step 6 — Assemble memory patch JSON

Build the patch JSON to pipe into `df-init --write-memory`:

```json
{
  "config": {
    "service": "<repo-directory-name>",
    "workspace": "<workspace_name or null>",
    "stack": {
      "runtime": "<stack_runtime>",
      "frontend": "<stack_frontend>",
      "test_cmd": "<test_cmd>"
    },
    "last_synced": "<head_sha>",
    "schema_version": 1,
    "node_types": { "custom": [] },
    "edge_staleness_threshold": 30,
    "edge_rel_types": {
      "builtin": ["depends_on", "uses", "persisted_in", "implements", "emits", "handles"],
      "custom": []
    },
    "graph_limits": { "max_nodes": 2000, "max_edges": 10000, "prune_min_age_commits": 90 },
    "classifiers": {}
  },
  "memory": {
    "schema_version": 1,
    "last_synced": "<head_sha>",
    "stack": {
      "runtime": "<stack_runtime>",
      "frontend": "<stack_frontend>",
      "test_cmd": "<test_cmd>",
      "key_dependencies": "<from call 2 stack.key_dependencies>"
    },
    "architecture": "<from call 2>",
    "conventions": "<from call 2>"
  },
  "nodes": {
    "schema_version": 1,
    "nodes": [
      {
        "id": "<type>:<file-path-with-slashes-as-dots-no-extension>",
        "name": "<bare filename without extension>",
        "type": "<type>",
        "file": "<relative-file-path>",
        "intent": "<from call 1>",
        "confidence": "<ai or manual>",
        "last_seen": "<head_sha>"
      }
    ]
  },
  "edges": {
    "schema_version": 1,
    "edges": [
      {
        "from": "<node id>",
        "to": "<node id>",
        "rel": "<rel-type>",
        "intent": "<from call 1>",
        "last_seen": "<head_sha>"
      }
    ]
  }
}
```

**Node ID format:** `<type>:<file-path-slug>` where file-path-slug is the file's relative path from repo root with `/` replaced by `.` and the last extension stripped. Example: `Entities/Comment.cs` → `entity:Entities.Comment`.

**Edge `from` field:** The node ID of the file that the edge was returned on in Call 1.

**Edge `to` field:** Map `to_file` paths from call 1 to node IDs using the same ID formula.

**Validation:** Check all edge `rel` values are in the allowed set. Skip edges with unrecognized `rel` and T2 inform: `[DevFlow] Warning: skipping edge with unknown rel type "<value>"`.

### Step 7 — Write memory

Run:

```bash
echo '<memory-patch-json>' | df-init --write-memory
```

If exit code is 0: proceed to Step 8.
If exit code is 1: HALT. Show the error output.

### Step 8 — Print verification checklist

```
[DevFlow] Initialization complete.

  ✓ .devflow/config.json written
  ✓ .devflow/branches/<branch_canonicalized>/memory.json written
  ✓ .devflow/branches/<branch_canonicalized>/nodes.json written (<N> nodes)
  ✓ .devflow/branches/<branch_canonicalized>/edges.json written (<N> edges)
  ✓ .devflow/branches/<branch_canonicalized>/memory.md generated
  ✓ .devflow/active symlink → branches/<branch_canonicalized>/
  ✓ .git/hooks/post-commit installed (--quick mode)
  ✓ .git/hooks/post-checkout installed (--quick mode)

To verify: run `df-init --scan` to confirm the repo is still classified correctly.
Run `cat .devflow/active/memory.md` to review what DevFlow knows about this repo.
```

---

## Re-init Mode

If `.devflow/` already exists, this skill runs the same flow but:
- In Step 5, only pass files with cleared `intent` or new unclassified files to the AI (not the full repo).
- In Step 7, `df-init --write-memory` automatically preserves `confidence: "manual"` nodes.

## --reset Mode

If the developer explicitly asks to reset, run:

```bash
df-init --reset
```

Then re-run the full init flow from Step 1.

---

## Guard Rails

1. **One gate only.** The only T3 gate is the final summary (Step 4). Never add gates before it. — because asking users to confirm machine-derivable data wastes time without adding safety.
2. **T1 for derivable decisions.** Stack detection, workspace name, file classification are T1 Silent. They are correct or correctable at the final gate. See `skills/_shared.md`.
3. **T2 for inferences.** Print what was detected before the gate (Step 3). Do not ask for pre-confirmation.
4. **Merge, not overwrite.** Re-init merges with existing `confidence: "manual"` nodes — never silently deletes them.
5. **Reality check.** Correctly classified nodes — leave them. Don't reclassify for the sake of it.

## You Will Be Tempted To

| Temptation | Reality |
|------------|---------|
| "Confirm stack detection before writing" | Auto-detect is correct. Show it in the summary gate instead. |
| "Ask about custom node types separately" | The summary gate covers all decisions. One gate. |
| "Show unclassified files batch for review" | Expanded auto-classifiers handle them. If truly ambiguous, show in summary. |
| "Ask about workspace name" | Derive from git remote or directory name (T1). Show in summary. |
| "Re-init overwrites everything for safety" | Re-init merges. Manual nodes are preserved. |

## Red Flags — STOP

- Writing memory before the T3 summary gate
- Adding any gate before Step 4
- Overwriting existing `confidence: "manual"` nodes
- Asking user to confirm stack detection before the summary

**One gate. Final. Then write.**

---

## Error Reference

| Error | What to do |
|---|---|
| "Not a git repo" | Tell developer to run `/init` inside a git repository. |
| "Missing prerequisite: jq" | Tell developer: `brew install jq` or `apt install jq`. |
| "Invalid memory patch JSON" | Check your assembled JSON for syntax errors and try again. |
| AI call timeout (both retries) | Nodes written without intent. T2 inform: intent will populate on next `df-sync`. |

Base directory for this skill: ~/.devflow/skills/init
