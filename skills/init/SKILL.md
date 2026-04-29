# Skill: init

# DevFlow Init

Initialize DevFlow memory for the current repository. Drives interactive stack confirmation, optional workspace configuration, AI-powered node/edge classification, and atomic memory write.

**When invoked:** `/init` in Claude Code while inside any git repo.

**Prerequisite:** `df-init` must be on PATH. Install DevFlow first if needed.

---

## Flow

### Step 1 — Scan the repo

Run:

```bash
df-init --scan
```

Parse the JSON output. Extract: `stack_hints`, `classified`, `unclassified`, `branch`, `branch_canonicalized`.

If the command fails (exit 1):
- If "Not a git repo": tell the developer to run `/init` inside a git repository. Stop.
- If "Missing prerequisite": show the missing tool name. Tell them to install it. Stop.
- Any other error: show the raw error and stop.

### Step 2 — Confirm detected stack

Show the developer what was found:

```
[DevFlow] I found the following stack in this repo:
  Runtime:  <inferred.runtime> (found: <files_found>)
  Frontend: <inferred.frontend>
  Test cmd: (not detected — I'll ask)

Is this correct?
  [Y] Yes
  [N] No, let me correct it
```

Wait for the developer's response. If N: ask for the correct values one at a time:
1. What is the runtime? (e.g. `dotnet-9`, `node`, `python-3.12`, `go-1.22`)
2. What is the frontend framework, if any? (e.g. `sveltekit`, `react`, `none`)
3. What command runs the tests? (e.g. `dotnet test`, `npm test`, `pytest`)

Store the confirmed values as `stack_runtime`, `stack_frontend`, `test_cmd`.

### Step 3 — Workspace name (optional)

Ask:

```
[DevFlow] Is this repo part of a multi-service workspace?
  [A] Yes — I'll give it a name
  [B] No — standalone repo
```

If A: ask for workspace name (e.g. "ovell"). Store as `workspace_name`. Register in `~/.devflow/workspaces/<name>.json` (create the file with `{"name": "<name>", "repos": ["<abs-repo-path>"]}` if it doesn't exist; append this repo path if it does).

If B: set `workspace_name = null`.

### Step 4 — Custom node types (only if unclassified files exist)

If `unclassified` list is empty: skip this step.

Otherwise ask:

```
[DevFlow] I found <N> files I couldn't classify. Would you like to define custom node types for them?
  [A] Yes — show me the files
  [B] No — treat them as untyped / let AI classify
```

If A: show unclassified files in batches of 10. For each batch, ask the developer to assign a type or skip. Collect `custom_node_types` and any manually-typed files.

If B: let the AI classify in Step 6.

### Step 5 — Review unclassified files (only if A chosen in Step 4)

For each batch of 10 unclassified files, show:

```
[DevFlow] Unclassified files (batch 1 of N):
  1. src/lib/utils/slug.ts
  2. src/lib/stores/auth.ts
  ...

For each file, type the node type (entity/service/route/contract/custom) or press Enter to skip:
```

Collect any typed assignments. These become `confidence: "manual"` nodes.

### Step 6 — AI: intent + classification + edges

**DEVFLOW_AI_MOCK=1 mode:** If `DEVFLOW_AI_MOCK` environment variable equals `1`, read from `~/.devflow/tests/fixtures/ai-responses/df-init-response.json` instead of calling the API. Parse the same JSON structure.

**Real mode:**

Make a single Claude API batch call with:
- All classified files + their type + first 50 lines of file content (or full file if < 50 lines)
- All unclassified files + their full content
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

On timeout: wait 5 seconds, retry once. On second failure: write nodes without `intent`, set `confidence: "ai"`, log: `[DevFlow] intent inference skipped — will retry on next df-sync`.

**Call 2 — Architecture/conventions for memory.json:**

Second call with the `architecture` and `conventions` classifier files:

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

### Step 7 — Assemble memory patch JSON

Build the patch JSON to pipe into `df-init --write-memory`:

```json
{
  "config": {
    "service": "<repo-directory-name>",
    "workspace": "<workspace_name or null>",
    "stack": "<stack_runtime>",
    "test_cmd": "<test_cmd>",
    "last_synced": "<head_sha from scan>",
    "schema_version": 1,
    "node_types": { "custom": ["<any custom types collected in steps 4-5>"] },
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
    "stack": "<from call 2>",
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
        "last_seen_sha": "<head_sha>"
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
        "last_seen_sha": "<head_sha>"
      }
    ]
  }
}
```

**Node ID format:** `<type>:<file-path-slug>` where file-path-slug is the file's relative path from repo root with `/` replaced by `.` and the extension stripped. Example: `Entities/Comment.cs` → `entity:Entities.Comment`.

**Edge `to` field:** Map `to_file` paths from call 1 to node IDs using the same ID formula.

**Validation before write:** Check all edge `rel` values are in the allowed set: `depends_on`, `uses`, `persisted_in`, `implements`, `emits`, `handles`, or any values in `config.edge_rel_types.custom`. Skip edges with unrecognized `rel` and log a warning: `[DevFlow] Warning: skipping edge with unknown rel type "<value>"`.

### Step 8 — Write memory

Run:

```bash
echo '<memory-patch-json>' | df-init --write-memory
```

If exit code is 0: proceed to Step 9.
If exit code is 1: show the error output and stop.

### Step 9 — Print verification checklist

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

To verify: run `df-init --scan` to confirm the repo is still classified correctly.
Run `cat .devflow/active/memory.md` to review what DevFlow knows about this repo.
```

---

## Re-init Mode

If `.devflow/` already exists, this skill runs the same flow but:
- In Step 6, only pass files with cleared `intent` or new unclassified files to the AI (not the full repo).
- In Step 8, `df-init --write-memory` automatically preserves `confidence: "manual"` nodes.

## --reset Mode

If the developer explicitly asks to reset (e.g. "reset DevFlow for this branch"), run:

```bash
df-init --reset
```

Then re-run the full init flow from Step 1.

---

## Error Reference

| Error | What to do |
|---|---|
| "Not a git repo" | Tell developer to run `/init` inside a git repository. |
| "Missing prerequisite: jq" | Tell developer: `brew install jq` or `apt install jq`. |
| "Invalid memory patch JSON" | Check your assembled JSON for syntax errors and try again. |
| AI call timeout (both retries) | Nodes written without intent. Tell developer intent will populate on next `df-sync`. |

Base directory for this skill: ~/.devflow/skills/init
