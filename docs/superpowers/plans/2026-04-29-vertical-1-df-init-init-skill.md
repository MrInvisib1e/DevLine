# Vertical 1 — `df-init` + `init` Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `df-init` (a shell script handling all mechanical init operations) and the `init` skill (a SKILL.md that drives interactive AI-powered initialization), so running `/init` in any git repo produces a fully initialized `.devflow/` directory.

**Architecture:** Two-phase protocol — `df-init --scan` outputs a classification manifest JSON; the `init` skill does interactive prompts + Claude API calls; `df-init --write-memory` consumes the assembled patch JSON and atomically writes all files. No AI logic lives in the shell script.

**Tech Stack:** bash (shellcheck-clean), bats (test framework), jq (JSON manipulation), Claude API (via skill's AI calls), standard POSIX tools.

---

## File Map

| Path | Role | Create/Modify |
|---|---|---|
| `bin/df-init` | Main shell script — scan + write-memory | Create |
| `skills/init/SKILL.md` | Init skill — interactive flow + AI calls | Create |
| `tests/df-init.bats` | All bats tests for df-init | Create |
| `tests/fixtures/sample-repo/` | Minimal git repo for tests | Create |
| `tests/fixtures/sample-repo/Program.cs` | Stack-hint fixture file | Create |
| `tests/fixtures/sample-repo/vite.config.ts` | Stack-hint fixture file | Create |
| `tests/fixtures/sample-repo/package.json` | Stack-hint fixture file | Create |
| `tests/fixtures/sample-repo/src/routes/+page.svelte` | Route-type fixture file | Create |
| `tests/fixtures/sample-repo/Entities/Comment.cs` | Entity-type fixture file | Create |
| `tests/fixtures/sample-repo/Services/CommentService.cs` | Service-type fixture file | Create |
| `tests/fixtures/sample-repo/Contracts/CommentCreatedEvent.cs` | Contract-type fixture file | Create |
| `tests/fixtures/sample-repo/src/lib/utils/slug.ts` | Unclassified file fixture | Create |
| `tests/fixtures/ai-responses/df-init-response.json` | Canned AI response for mock mode | Create |

---

## Task 1: Repository Scaffolding

Set up directories and install bats.

**Files:**
- Create: `bin/` directory
- Create: `skills/init/` directory
- Create: `tests/fixtures/sample-repo/src/routes/` directory
- Create: `tests/fixtures/sample-repo/Entities/` directory
- Create: `tests/fixtures/sample-repo/Services/` directory
- Create: `tests/fixtures/sample-repo/Contracts/` directory
- Create: `tests/fixtures/sample-repo/src/lib/utils/` directory
- Create: `tests/fixtures/ai-responses/` directory

- [ ] **Step 1: Check if bats is installed**

```bash
bats --version
```

Expected: prints version like `Bats 1.x.x`. If not found, install:
```bash
brew install bats-core
```

- [ ] **Step 2: Create directory structure**

```bash
mkdir -p bin
mkdir -p skills/init
mkdir -p tests/fixtures/sample-repo/src/routes
mkdir -p tests/fixtures/sample-repo/Entities
mkdir -p tests/fixtures/sample-repo/Services
mkdir -p tests/fixtures/sample-repo/Contracts
mkdir -p tests/fixtures/sample-repo/src/lib/utils
mkdir -p tests/fixtures/ai-responses
```

- [ ] **Step 3: Create fixture files for sample-repo**

`tests/fixtures/sample-repo/Program.cs`:
```csharp
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();
app.Run();
```

`tests/fixtures/sample-repo/vite.config.ts`:
```ts
import { defineConfig } from 'vite';
import { sveltekit } from '@sveltejs/kit/vite';
export default defineConfig({ plugins: [sveltekit()] });
```

`tests/fixtures/sample-repo/package.json`:
```json
{ "name": "sample-repo", "version": "1.0.0", "scripts": {} }
```

`tests/fixtures/sample-repo/src/routes/+page.svelte`:
```svelte
<h1>Home</h1>
```

`tests/fixtures/sample-repo/Entities/Comment.cs`:
```csharp
public class Comment {
    public int Id { get; set; }
    public string Body { get; set; } = "";
    public bool IsHidden { get; set; }
}
```

`tests/fixtures/sample-repo/Services/CommentService.cs`:
```csharp
public class CommentService {
    public List<Comment> List() => new();
}
```

`tests/fixtures/sample-repo/Contracts/CommentCreatedEvent.cs`:
```csharp
public record CommentCreatedEvent(int CommentId);
```

`tests/fixtures/sample-repo/src/lib/utils/slug.ts`:
```ts
export function slugify(s: string) { return s.toLowerCase().replace(/\s+/g, '-'); }
```

- [ ] **Step 4: Initialize sample-repo as a git repo and add all files**

```bash
cd tests/fixtures/sample-repo && git init && git add . && git commit -m "initial" && cd ../../..
```

Expected: `[main (root-commit) xxxxxxx] initial` with 7+ files

- [ ] **Step 5: Create canned AI response fixture**

`tests/fixtures/ai-responses/df-init-response.json`:
```json
{
  "call1": [
    {
      "file": "Entities/Comment.cs",
      "type": "entity",
      "confidence": "ai",
      "intent": "Soft-deletable content unit attached to a story",
      "edges": [
        { "to_file": "Services/CommentService.cs", "rel": "uses", "intent": "owned by service" }
      ]
    },
    {
      "file": "Services/CommentService.cs",
      "type": "service",
      "confidence": "ai",
      "intent": "Owns all comment mutations",
      "edges": []
    },
    {
      "file": "Contracts/CommentCreatedEvent.cs",
      "type": "contract",
      "confidence": "ai",
      "intent": "Event emitted when a new comment is created",
      "edges": []
    },
    {
      "file": "src/routes/+page.svelte",
      "type": "route",
      "confidence": "ai",
      "intent": "Home page route",
      "edges": []
    },
    {
      "file": "src/lib/utils/slug.ts",
      "type": "unclassified",
      "confidence": "ai",
      "intent": "URL slug utility",
      "edges": []
    }
  ],
  "call2": {
    "stack": {
      "runtime": "dotnet-9",
      "frontend": "sveltekit",
      "test_cmd": "dotnet test",
      "key_dependencies": ["SvelteKit", "ASP.NET Core"]
    },
    "architecture": {
      "layers": ["api", "services", "entities"],
      "folder_structure": {
        "Entities": "domain models",
        "Services": "business logic",
        "Contracts": "events and messages",
        "src/routes": "SvelteKit pages"
      },
      "patterns": ["vertical slices", "event-driven"]
    },
    "conventions": {
      "naming": ["PascalCase for C# classes", "kebab-case for Svelte routes"],
      "anti_patterns": [],
      "file_structure": ["one class per file", "events in Contracts/"]
    }
  }
}
```

- [ ] **Step 6: Commit scaffolding**

```bash
git add bin/ skills/ tests/
git commit -m "chore: scaffold vertical-1 directories and fixtures"
```

---

## Task 2: Write Failing Tests (TDD Baseline)

Write all bats tests before implementing `df-init`. Tests will fail until Tasks 3-7 are complete.

**Files:**
- Create: `tests/df-init.bats`

- [ ] **Step 1: Create the test file**

`tests/df-init.bats`:
```bash
#!/usr/bin/env bats

# ─── helpers ───────────────────────────────────────────────────────────────────

setup() {
  # Create a temp dir and clone the sample-repo into it
  export REPO="$(mktemp -d)"
  cp -r "$BATS_TEST_DIRNAME/fixtures/sample-repo/." "$REPO/"
  (cd "$REPO" && git init && git add . && git commit -m "initial" --quiet)
  export FIXTURE_AI="$BATS_TEST_DIRNAME/fixtures/ai-responses/df-init-response.json"
  export DF_INIT="$BATS_TEST_DIRNAME/../bin/df-init"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

teardown() {
  rm -rf "$REPO"
}

# ─── --version ─────────────────────────────────────────────────────────────────

@test "df-init --version prints DevFlow version and exits 0" {
  run "$DF_INIT" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ DevFlow ]]
}

# ─── --scan output ─────────────────────────────────────────────────────────────

@test "--scan outputs valid JSON" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq . > /dev/null
}

@test "--scan output has required top-level keys" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.schema_version' > /dev/null
  echo "$output" | jq -e '.branch' > /dev/null
  echo "$output" | jq -e '.branch_canonicalized' > /dev/null
  echo "$output" | jq -e '.classified' > /dev/null
  echo "$output" | jq -e '.unclassified' > /dev/null
  echo "$output" | jq -e '.stack_hints' > /dev/null
}

@test "--scan classifies Entities/Comment.cs as entity" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.classified[] | select(.file == "Entities/Comment.cs") | select(.type == "entity")' > /dev/null
}

@test "--scan classifies Services/CommentService.cs as service" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.classified[] | select(.file == "Services/CommentService.cs") | select(.type == "service")' > /dev/null
}

@test "--scan classifies Contracts/CommentCreatedEvent.cs as contract" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.classified[] | select(.file == "Contracts/CommentCreatedEvent.cs") | select(.type == "contract")' > /dev/null
}

@test "--scan classifies src/routes/+page.svelte as route" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.classified[] | select(.file == "src/routes/+page.svelte") | select(.type == "route")' > /dev/null
}

@test "--scan puts src/lib/utils/slug.ts in unclassified" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.unclassified[] | select(.file == "src/lib/utils/slug.ts")' > /dev/null
}

@test "--scan stack_hints detects dotnet and sveltekit" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.stack_hints.files_found | index("Program.cs")' > /dev/null
  echo "$output" | jq -e '.stack_hints.files_found | index("vite.config.ts")' > /dev/null
}

# ─── Branch canonicalization ───────────────────────────────────────────────────

@test "--scan canonicalizes branch names with slashes" {
  (cd "$REPO" && git checkout -b feature/comments --quiet)
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  branch_canon=$(echo "$output" | jq -r '.branch_canonicalized')
  [ "$branch_canon" = "feature__comments" ]
}

@test "--scan canonicalizes nested branch names" {
  (cd "$REPO" && git checkout -b fix/auth/token-expiry --quiet)
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  branch_canon=$(echo "$output" | jq -r '.branch_canonicalized')
  [ "$branch_canon" = "fix__auth__token-expiry" ]
}

# ─── Fresh init ────────────────────────────────────────────────────────────────

_build_patch() {
  local repo="$1"
  local branch_canon
  branch_canon=$(cd "$repo" && "$DF_INIT" --scan | jq -r '.branch_canonicalized')
  cat "$FIXTURE_AI" | jq --arg branch "$branch_canon" --arg sha "$(cd "$repo" && git rev-parse HEAD)" '{
    config: {
      service: "sample-repo",
      workspace: null,
      stack: "dotnet-9",
      test_cmd: "dotnet test",
      last_synced: $sha,
      schema_version: 1,
      node_types: { custom: [] },
      edge_staleness_threshold: 30,
      edge_rel_types: { builtin: ["depends_on","uses","persisted_in","implements","emits","handles"], custom: [] },
      graph_limits: { max_nodes: 2000, max_edges: 10000, prune_min_age_commits: 90 },
      classifiers: {}
    },
    memory: {
      schema_version: 1,
      last_synced: $sha,
      stack: .call2.stack,
      architecture: .call2.architecture,
      conventions: .call2.conventions
    },
    nodes: {
      schema_version: 1,
      nodes: (.call1 | map(select(.type != "unclassified") | {
        id: (.type + ":" + (.file | gsub("/"; ".") | sub("\\.[^.]+$"; ""))),
        name: (.file | split("/") | last | sub("\\.[^.]+$"; "")),
        type: .type,
        file: .file,
        intent: .intent,
        confidence: .confidence,
        last_seen_sha: $sha
      }))
    },
    edges: { schema_version: 1, edges: [] }
  }'
}

@test "fresh init: all required files created" {
  local patch
  patch=$(_build_patch "$REPO")
  run bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"
  [ "$status" -eq 0 ]
  [ -f "$REPO/.devflow/config.json" ]
  [ -f "$REPO/.devflow/branches/$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)"/memory.json ]
  [ -f "$REPO/.devflow/branches/$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)"/nodes.json ]
  [ -f "$REPO/.devflow/branches/$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)"/edges.json ]
  [ -f "$REPO/.devflow/branches/$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)"/memory.md ]
}

@test "fresh init: active symlink points to current branch" {
  local patch
  patch=$(_build_patch "$REPO")
  run bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"
  [ "$status" -eq 0 ]
  [ -L "$REPO/.devflow/active" ]
  local branch_canon
  branch_canon=$(cd "$REPO" && "$DF_INIT" --scan | jq -r '.branch_canonicalized')
  local target
  target=$(readlink "$REPO/.devflow/active")
  [[ "$target" == *"$branch_canon"* ]]
}

@test "fresh init: config.json dirty flag is cleared" {
  local patch
  patch=$(_build_patch "$REPO")
  run bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"
  [ "$status" -eq 0 ]
  run bash -c "jq -e '.dirty == false or .dirty == null' '$REPO/.devflow/config.json'"
  [ "$status" -eq 0 ]
}

@test "fresh init: all JSON files are valid JSON" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"
  local branch
  branch=$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)
  jq . "$REPO/.devflow/config.json" > /dev/null
  jq . "$REPO/.devflow/branches/$branch/memory.json" > /dev/null
  jq . "$REPO/.devflow/branches/$branch/nodes.json" > /dev/null
  jq . "$REPO/.devflow/branches/$branch/edges.json" > /dev/null
}

@test "fresh init: git hooks installed and executable" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"
  [ -x "$REPO/.git/hooks/post-commit" ]
  [ -x "$REPO/.git/hooks/post-checkout" ]
  grep -q "df-sync" "$REPO/.git/hooks/post-commit"
  grep -q "df-sync" "$REPO/.git/hooks/post-checkout"
}

@test "fresh init: nodes.json has schema_version 1" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"
  local branch
  branch=$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)
  run jq -e '.schema_version == 1' "$REPO/.devflow/branches/$branch/nodes.json"
  [ "$status" -eq 0 ]
}

# ─── Re-init (patch forward) ──────────────────────────────────────────────────

@test "re-init: manual-confidence node intent is preserved" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"

  # Manually set confidence on a node
  local branch
  branch=$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)
  local nodes_file="$REPO/.devflow/branches/$branch/nodes.json"
  local tmp
  tmp=$(mktemp)
  jq '(.nodes[] | select(.file == "Entities/Comment.cs")).confidence = "manual" |
      (.nodes[] | select(.file == "Entities/Comment.cs")).intent = "MANUAL INTENT DO NOT OVERWRITE"' \
    "$nodes_file" > "$tmp" && mv "$tmp" "$nodes_file"

  # Re-init with updated patch
  run bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"
  [ "$status" -eq 0 ]

  # Manual intent must survive
  run jq -r '.nodes[] | select(.file == "Entities/Comment.cs") | .intent' "$nodes_file"
  [ "$output" = "MANUAL INTENT DO NOT OVERWRITE" ]
}

@test "re-init: sha updated in config.json" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"

  # Make a new commit
  (cd "$REPO" && touch newfile.txt && git add newfile.txt && git commit -m "second commit" --quiet)

  # Rebuild patch with new sha
  local new_patch
  new_patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$new_patch' | '$DF_INIT' --write-memory"

  local new_sha
  new_sha=$(cd "$REPO" && git rev-parse HEAD)
  run jq -r '.last_synced' "$REPO/.devflow/config.json"
  [ "$output" = "$new_sha" ]
}

# ─── --reset ──────────────────────────────────────────────────────────────────

@test "--reset: snapshot created before wipe" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"
  run bash -c "cd '$REPO' && '$DF_INIT' --reset"
  [ "$status" -eq 0 ]
  # At least one snapshot directory should exist
  local count
  count=$(ls -d "$REPO/.devflow/snapshots/"*/ 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -ge 1 ]
}

@test "--reset: current branch directory wiped" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"
  local branch
  branch=$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)
  run bash -c "cd '$REPO' && '$DF_INIT' --reset"
  [ "$status" -eq 0 ]
  # Branch dir should NOT exist after --reset (until --write-memory re-creates it)
  [ ! -d "$REPO/.devflow/branches/$branch" ]
}

@test "--reset: other branches untouched" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"

  # Create a second branch and init it
  (cd "$REPO" && git checkout -b other-branch --quiet)
  local patch2
  patch2=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch2' | '$DF_INIT' --write-memory"

  # Reset back on main
  (cd "$REPO" && git checkout main --quiet)
  bash -c "cd '$REPO' && '$DF_INIT' --reset"

  # other-branch should still have its files
  [ -d "$REPO/.devflow/branches/other-branch" ]
}

# ─── Hook idempotency ─────────────────────────────────────────────────────────

@test "hook idempotency: running --write-memory twice does not duplicate df-sync calls" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"

  local count
  count=$(grep -c "df-sync$" "$REPO/.git/hooks/post-commit")
  [ "$count" -eq 1 ]
}

@test "hook idempotency: existing non-DevFlow hook content is preserved" {
  # Write a pre-existing hook without DevFlow header
  mkdir -p "$REPO/.git/hooks"
  cat > "$REPO/.git/hooks/post-commit" << 'HOOK'
#!/bin/bash
echo "existing hook"
HOOK
  chmod +x "$REPO/.git/hooks/post-commit"

  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"

  # Original content must survive
  grep -q "existing hook" "$REPO/.git/hooks/post-commit"
  # DevFlow call must also be present
  grep -q "df-sync" "$REPO/.git/hooks/post-commit"
}

@test "hook idempotency: DevFlow-managed hook is replaced not appended" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"

  # Simulate first write by running again
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"

  # Should only have one DevFlow managed header
  local count
  count=$(grep -c "DevFlow managed" "$REPO/.git/hooks/post-commit")
  [ "$count" -eq 1 ]
}

# ─── Error paths ──────────────────────────────────────────────────────────────

@test "df-init exits 1 and prints error when not in git repo" {
  local tmpdir
  tmpdir=$(mktemp -d)
  run bash -c "cd '$tmpdir' && '$DF_INIT' --scan"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Not a git repo" ]]
  rm -rf "$tmpdir"
}

@test "--write-memory exits 1 on invalid JSON input" {
  run bash -c "cd '$REPO' && echo 'not-json' | '$DF_INIT' --write-memory"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid memory patch JSON" ]]
}

@test "--write-memory leaves dirty:true on write failure" {
  # Pre-create config so we can make it unwritable
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && echo '$patch' | '$DF_INIT' --write-memory"

  # Make nodes.json unwritable so write fails
  local branch
  branch=$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)
  chmod 444 "$REPO/.devflow/branches/$branch/nodes.json"

  # Build a new patch for re-init
  local patch2
  patch2=$(_build_patch "$REPO")
  run bash -c "cd '$REPO' && echo '$patch2' | '$DF_INIT' --write-memory"
  # Should fail
  [ "$status" -ne 0 ]

  # dirty flag must survive
  run jq -e '.dirty == true' "$REPO/.devflow/config.json"
  [ "$status" -eq 0 ]

  chmod 644 "$REPO/.devflow/branches/$branch/nodes.json"
}

# ─── CI mode ──────────────────────────────────────────────────────────────────

@test "CI mode: df-init --scan works even without .devflow (it creates it)" {
  # df-init is special — it always runs (no CI skip guard)
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run tests to confirm all fail (no implementation yet)**

```bash
bats tests/df-init.bats
```

Expected: All tests fail with "command not found" or similar — this is expected (no implementation yet).

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/
git commit -m "test: add df-init.bats test suite (all failing — TDD baseline)"
```

---

## Task 3: Implement `df-init --version` and `--scan`

Build the first half of the df-init script.

**Files:**
- Create: `bin/df-init`

- [ ] **Step 1: Create the script with shebang, version, and prerequisite checks**

`bin/df-init`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# ─── constants ────────────────────────────────────────────────────────────────

DEVFLOW_VERSION="0.1.0"

DEFAULT_CLASSIFIERS=(
  "entity:**/Entities/*.cs:**/Models/*.cs:**/Domain/**/*.cs"
  "route:*Controller.cs:*Endpoint.cs:**/pages/**/*.svelte:**/routes/**/*.ts:**/routes/**/*.svelte"
  "contract:**/Contracts/**:**/Events/**:**/Messages/**"
  "service:**/Services/*.cs:**/Handlers/*.cs"
  "conventions:.editorconfig:*.globalconfig:.eslintrc*:*.prettierrc*"
  "architecture:Program.cs:Startup.cs:appsettings*.json:vite.config.*"
)

# ─── helpers ──────────────────────────────────────────────────────────────────

err() { echo "[DevFlow] $*" >&2; }

check_prereqs() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Not a git repo. Run df-init inside a git repository."
    exit 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    err "Missing prerequisite: jq >= 1.6 is required. Install with: brew install jq"
    exit 1
  fi
}

canonicalize_branch() {
  echo "${1//\//__}"
}

# Match a file against glob patterns for a given classifier type.
# Returns the type string if matched, empty string if not.
classify_file() {
  local file="$1"
  local type=""
  for entry in "${DEFAULT_CLASSIFIERS[@]}"; do
    local entry_type="${entry%%:*}"
    local patterns="${entry#*:}"
    IFS=':' read -ra pats <<< "$patterns"
    for pat in "${pats[@]}"; do
      # Use bash glob matching via case statement
      case "$file" in
        $pat)
          type="$entry_type"
          break 2
          ;;
      esac
    done
  done
  echo "$type"
}

# ─── --version ────────────────────────────────────────────────────────────────

cmd_version() {
  echo "DevFlow $DEVFLOW_VERSION"
  exit 0
}

# ─── --scan ───────────────────────────────────────────────────────────────────

cmd_scan() {
  check_prereqs

  local head_sha
  head_sha=$(git rev-parse HEAD 2>/dev/null || echo "none")

  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

  local branch_canon
  branch_canon=$(canonicalize_branch "$branch")

  # Enumerate all tracked files
  local all_files
  mapfile -t all_files < <(git ls-files)

  local classified_json="[]"
  local unclassified_json="[]"
  local stack_files=()

  # Track which stack hint files we found
  local stack_hints_files=()

  for f in "${all_files[@]}"; do
    local t
    t=$(classify_file "$f")

    # Collect stack hint files
    case "$f" in
      Program.cs|Startup.cs|*.csproj|*.sln) stack_hints_files+=("$f") ;;
      vite.config.*) stack_hints_files+=("$f") ;;
      package.json) stack_hints_files+=("$f") ;;
    esac

    if [[ -n "$t" && "$t" != "conventions" && "$t" != "architecture" ]]; then
      classified_json=$(echo "$classified_json" | jq \
        --arg file "$f" --arg type "$t" \
        '. + [{"file": $file, "type": $type, "confidence": "high"}]')
    elif [[ -z "$t" ]]; then
      unclassified_json=$(echo "$unclassified_json" | jq \
        --arg file "$f" \
        '. + [{"file": $file}]')
    fi
  done

  # Infer stack from hints
  local inferred_runtime="unknown"
  local inferred_frontend="unknown"
  for f in "${stack_hints_files[@]}"; do
    case "$f" in
      Program.cs|Startup.cs|*.csproj|*.sln) inferred_runtime="dotnet-9" ;;
      vite.config.ts|vite.config.js) inferred_frontend="sveltekit" ;;
    esac
  done

  # Build stack_hints_files JSON array
  local hints_json="[]"
  for f in "${stack_hints_files[@]}"; do
    hints_json=$(echo "$hints_json" | jq --arg f "$f" '. + [$f]')
  done

  jq -n \
    --argjson schema_version 1 \
    --arg head_sha "$head_sha" \
    --arg branch "$branch" \
    --arg branch_canonicalized "$branch_canon" \
    --argjson classified "$classified_json" \
    --argjson unclassified "$unclassified_json" \
    --argjson hints_files "$hints_json" \
    --arg runtime "$inferred_runtime" \
    --arg frontend "$inferred_frontend" \
    '{
      schema_version: $schema_version,
      head_sha: $head_sha,
      branch: $branch,
      branch_canonicalized: $branch_canonicalized,
      classified: $classified,
      unclassified: $unclassified,
      stack_hints: {
        files_found: $hints_files,
        inferred: { runtime: $runtime, frontend: $frontend }
      }
    }'
  exit 0
}

# ─── dispatch ─────────────────────────────────────────────────────────────────

case "${1:-}" in
  --version) cmd_version ;;
  --scan)    cmd_scan    ;;
  --write-memory) echo "[DevFlow] --write-memory: not yet implemented" >&2; exit 1 ;;
  --reset)        echo "[DevFlow] --reset: not yet implemented" >&2; exit 1 ;;
  *) echo "[DevFlow] Unknown command: ${1:-}. Use --scan, --write-memory, --reset, or --version." >&2; exit 1 ;;
esac
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x bin/df-init
```

- [ ] **Step 3: Quick smoke test**

```bash
cd tests/fixtures/sample-repo && ../../bin/df-init --scan | jq .
```

Expected: Valid JSON with `classified`, `unclassified`, `stack_hints`, `branch_canonicalized` keys.

- [ ] **Step 4: Run the scan-related tests**

```bash
bats tests/df-init.bats --filter "version\|scan\|canonicali"
```

Expected: `--version`, `--scan output`, and `--scan classifies` tests PASS. Others still fail.

- [ ] **Step 5: Commit**

```bash
git add bin/df-init
git commit -m "feat: implement df-init --version and --scan"
```

---

## Task 4: Implement `df-init --write-memory`

The main write phase — atomic file writes, symlink, hooks.

**Files:**
- Modify: `bin/df-init` (add `cmd_write_memory` function and atomic write helpers)

- [ ] **Step 1: Add atomic write helper and `cmd_write_memory` to df-init**

Add after the `cmd_scan` function and before the dispatch section:

```bash
# ─── atomic write helper ──────────────────────────────────────────────────────

# atomic_write <file> <content>
atomic_write() {
  local file="$1"
  local content="$2"
  local tmp="${file}.tmp"
  printf '%s' "$content" > "$tmp"
  # fsync if available (Linux), ignore on macOS where sync is different
  sync 2>/dev/null || true
  mv "$tmp" "$file"
}

# ─── install or append hook ───────────────────────────────────────────────────

install_hook() {
  local hook_file="$1"
  local hook_body="$2"
  local devflow_header="# DevFlow managed"
  local managed_content
  managed_content="$(printf '%s\n#!/usr/bin/env bash\n%s\n%s\n' "$devflow_header" "" "$hook_body")"

  if [[ -f "$hook_file" ]]; then
    if grep -q "^${devflow_header}" "$hook_file" 2>/dev/null; then
      # Overwrite the whole file — it's ours
      printf '#!/usr/bin/env bash\n%s\n\n%s\n' "$devflow_header" "$hook_body" > "$hook_file"
    else
      # Append to existing non-DevFlow hook
      printf '\n%s\n%s\n' "$devflow_header" "$hook_body" >> "$hook_file"
    fi
  else
    printf '#!/usr/bin/env bash\n%s\n\n%s\n' "$devflow_header" "$hook_body" > "$hook_file"
  fi
  chmod +x "$hook_file"
}

# ─── generate memory.md ───────────────────────────────────────────────────────

render_memory_md() {
  local memory_json="$1"
  local nodes_json="$2"
  local edges_json="$3"

  local stack_runtime stack_frontend test_cmd
  stack_runtime=$(echo "$memory_json" | jq -r '.stack.runtime // "unknown"')
  stack_frontend=$(echo "$memory_json" | jq -r '.stack.frontend // "unknown"')
  test_cmd=$(echo "$memory_json" | jq -r '.stack.test_cmd // "unknown"')

  local md
  md="# DevFlow Memory\n\n"
  md+="## Stack\n\n"
  md+="- Runtime: ${stack_runtime}\n"
  md+="- Frontend: ${stack_frontend}\n"
  md+="- Test: ${test_cmd}\n\n"
  md+="## Graph\n\n"

  # Render each node with its edges
  while IFS= read -r node; do
    local node_id node_name node_type node_intent
    node_id=$(echo "$node" | jq -r '.id')
    node_name=$(echo "$node" | jq -r '.name')
    node_type=$(echo "$node" | jq -r '.type')
    node_intent=$(echo "$node" | jq -r '.intent // ""')

    md+="${node_name} [${node_type}]"
    if [[ -n "$node_intent" ]]; then
      md+=" — ${node_intent}"
    fi
    md+="\n"

    # Find edges from this node
    while IFS= read -r edge; do
      local rel to_id intent
      rel=$(echo "$edge" | jq -r '.rel')
      to_id=$(echo "$edge" | jq -r '.to')
      intent=$(echo "$edge" | jq -r '.intent // ""')
      # Get target name
      local to_name
      to_name=$(echo "$nodes_json" | jq -r --arg id "$to_id" '.nodes[] | select(.id == $id) | .name')
      md+="  ${rel} → ${to_name:-$to_id}"
      if [[ -n "$intent" ]]; then
        md+=" (${intent})"
      fi
      md+="\n"
    done < <(echo "$edges_json" | jq -c --arg id "$node_id" '.edges[] | select(.from == $id)')

  done < <(echo "$nodes_json" | jq -c '.nodes[]')

  printf '%b' "$md"
}

# ─── --write-memory ───────────────────────────────────────────────────────────

cmd_write_memory() {
  check_prereqs

  # Read patch JSON from stdin
  local patch
  patch=$(cat)

  # Validate JSON
  if ! echo "$patch" | jq . >/dev/null 2>&1; then
    err "Invalid memory patch JSON. Aborting write."
    exit 1
  fi

  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  local branch_canon
  branch_canon=$(canonicalize_branch "$branch")

  local devflow_dir=".devflow"
  local branch_dir="${devflow_dir}/branches/${branch_canon}"
  local snapshots_dir="${devflow_dir}/snapshots"

  # Set dirty flag before any writes (create config.json early if needed)
  mkdir -p "$branch_dir"
  local config_file="${devflow_dir}/config.json"

  # Extract each section from patch
  local config_content memory_content nodes_content edges_content
  config_content=$(echo "$patch" | jq '.config + {dirty: true}')
  memory_content=$(echo "$patch" | jq '.memory')
  nodes_content=$(echo "$patch" | jq '.nodes')
  edges_content=$(echo "$patch" | jq '.edges')

  # Acquire lock (use PID file fallback if flock unavailable)
  local lock_file="${devflow_dir}/sync.lock"
  local lock_fd
  if command -v flock >/dev/null 2>&1; then
    exec {lock_fd}>"$lock_file"
    if ! flock -n "$lock_fd"; then
      err "sync already running — skipping"
      exit 0
    fi
  else
    # PID-based lock fallback
    if [[ -f "$lock_file" ]]; then
      local old_pid
      old_pid=$(cat "$lock_file" 2>/dev/null || echo "")
      if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        err "sync already running — skipping"
        exit 0
      fi
    fi
    echo $$ > "$lock_file"
  fi

  # Set dirty:true before writes
  atomic_write "$config_file" "$(echo "$config_content" | jq '.')"

  # Re-init mode: preserve manual-confidence nodes
  local existing_nodes_file="${branch_dir}/nodes.json"
  if [[ -f "$existing_nodes_file" ]]; then
    # Merge: keep manual-confidence nodes' intent from existing
    nodes_content=$(jq -s '
      .[0] as $new | .[1] as $existing |
      $new | .nodes = (.nodes | map(
        . as $node |
        ($existing.nodes[] | select(.id == $node.id and .confidence == "manual")) as $manual |
        if $manual then $manual else $node end
      ))
    ' <(echo "$nodes_content") <(cat "$existing_nodes_file"))
  fi

  # Atomic writes
  atomic_write "${branch_dir}/memory.json" "$(echo "$memory_content" | jq '.')"
  atomic_write "${branch_dir}/nodes.json"  "$(echo "$nodes_content" | jq '.')"
  atomic_write "${branch_dir}/edges.json"  "$(echo "$edges_content" | jq '.')"

  # Render memory.md
  local memory_md
  memory_md=$(render_memory_md "$memory_content" "$nodes_content" "$edges_content")
  atomic_write "${branch_dir}/memory.md" "$memory_md"

  # Create/update active symlink
  ln -sfn "branches/${branch_canon}" "${devflow_dir}/active"

  # Validate all writes
  for f in "$config_file" "${branch_dir}/memory.json" "${branch_dir}/nodes.json" "${branch_dir}/edges.json" "${branch_dir}/memory.md"; do
    if [[ ! -f "$f" ]]; then
      err "Write failed: $f. Check disk space and permissions."
      exit 1
    fi
  done
  # Validate JSON files
  for f in "$config_file" "${branch_dir}/memory.json" "${branch_dir}/nodes.json" "${branch_dir}/edges.json"; do
    if ! jq . "$f" >/dev/null 2>&1; then
      err "Write failed: $f is not valid JSON."
      exit 1
    fi
  done

  # Install git hooks
  local hooks_dir=".git/hooks"
  if [[ -d "$hooks_dir" ]]; then
    install_hook "${hooks_dir}/post-commit" "df-sync"
    install_hook "${hooks_dir}/post-checkout" '[ "$3" = "1" ] || exit 0
df-sync --branch-switch'
  fi

  # Clear dirty flag
  local config_clean
  config_clean=$(echo "$config_content" | jq '.dirty = false')
  atomic_write "$config_file" "$(echo "$config_clean" | jq '.')"

  # Release lock
  if command -v flock >/dev/null 2>&1; then
    flock -u "$lock_fd"
  else
    rm -f "$lock_file"
  fi

  exit 0
}
```

Replace the `--write-memory` dispatch line:
```bash
  --write-memory) cmd_write_memory ;;
```

- [ ] **Step 2: Run write-memory-related tests**

```bash
bats tests/df-init.bats --filter "fresh init\|re-init\|idempotency\|Error\|dirty"
```

Expected: Most fresh init tests pass. Some may still fail — check output carefully.

- [ ] **Step 3: Commit**

```bash
git add bin/df-init
git commit -m "feat: implement df-init --write-memory with atomic writes and hook install"
```

---

## Task 5: Implement `df-init --reset`

**Files:**
- Modify: `bin/df-init` (add `cmd_reset` function)

- [ ] **Step 1: Add `cmd_reset` to df-init after `cmd_write_memory`**

```bash
# ─── --reset ──────────────────────────────────────────────────────────────────

cmd_reset() {
  check_prereqs

  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  local branch_canon
  branch_canon=$(canonicalize_branch "$branch")

  local devflow_dir=".devflow"
  local branch_dir="${devflow_dir}/branches/${branch_canon}"
  local snapshots_dir="${devflow_dir}/snapshots"

  if [[ ! -d "$branch_dir" ]]; then
    err "No .devflow/branches/${branch_canon}/ found. Nothing to reset."
    exit 0
  fi

  # Snapshot current branch files before wipe
  local timestamp
  timestamp=$(date +%Y%m%d%H%M%S)
  local snapshot_dir="${snapshots_dir}/${timestamp}"
  mkdir -p "$snapshot_dir"
  cp -r "${branch_dir}/." "$snapshot_dir/"

  # Wipe current branch directory only
  rm -rf "$branch_dir"

  echo "[DevFlow] Reset complete. Memory rebuilt from scratch for branch ${branch}."
  echo "[DevFlow] Snapshot saved to ${snapshot_dir}"
  echo "[DevFlow] Run df-init --write-memory to reinitialize."
  exit 0
}
```

Update dispatch:
```bash
  --reset) cmd_reset ;;
```

- [ ] **Step 2: Run reset tests**

```bash
bats tests/df-init.bats --filter "reset"
```

Expected: All `--reset` tests pass.

- [ ] **Step 3: Commit**

```bash
git add bin/df-init
git commit -m "feat: implement df-init --reset with snapshot-before-wipe"
```

---

## Task 6: Run Full Test Suite and Fix Failures

- [ ] **Step 1: Run all tests**

```bash
bats tests/df-init.bats
```

Expected: All tests pass. If any fail, read the error output carefully.

- [ ] **Step 2: Run shellcheck**

```bash
shellcheck bin/df-init
```

Expected: No errors, no warnings. Fix any issues found.

Common shellcheck fixes:
- `SC2206` (array splitting): use `mapfile -t arr < <(cmd)` instead of `arr=($(cmd))`
- `SC2155` (declare and assign): split `local x=$(...)` into `local x` then `x=$(...)` 
- `SC2064` (trap quoting): use `'` not `"` for trap signals if not expanding variables

- [ ] **Step 3: Fix any failing tests or shellcheck issues, then re-run both**

```bash
bats tests/df-init.bats && shellcheck bin/df-init
```

Expected: All tests pass, shellcheck clean.

- [ ] **Step 4: Commit fixes**

```bash
git add bin/df-init tests/df-init.bats
git commit -m "fix: pass all df-init.bats tests and shellcheck"
```

---

## Task 7: Write `init` Skill (SKILL.md)

The skill drives the interactive conversation in Claude Code. It calls `df-init --scan`, asks clarifying questions, makes Claude API calls, and calls `df-init --write-memory`.

**Files:**
- Create: `skills/init/SKILL.md`

- [ ] **Step 1: Write the skill file**

`skills/init/SKILL.md`:
```markdown
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
```
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
```

On timeout: wait 5 seconds, retry once. On second failure: write nodes without `intent`, set `confidence: "ai"`, log: `[DevFlow] intent inference skipped — will retry on next df-sync`.

**Call 2 — Architecture/conventions for memory.json:**

Second call with the `architecture` and `conventions` classifier files:

```
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
```

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
    "stack": <from call 2>,
    "architecture": <from call 2>,
    "conventions": <from call 2>
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
```

- [ ] **Step 2: Commit the skill**

```bash
git add skills/init/SKILL.md
git commit -m "feat: add init skill SKILL.md"
```

---

## Task 8: End-to-End Verification

**Files:** No new files — this task verifies the complete vertical works in real repos.

- [ ] **Step 1: Run the full test suite one final time**

```bash
bats tests/df-init.bats
```

Expected: ALL tests pass.

- [ ] **Step 2: Run shellcheck**

```bash
shellcheck bin/df-init
```

Expected: No errors, no warnings.

- [ ] **Step 3: Test with DEVFLOW_AI_MOCK=1 on the sample-repo fixture**

This simulates the full `/init` flow without real API calls. Manually simulate the skill steps:

```bash
# In the sample-repo fixture
cd tests/fixtures/sample-repo

# Step 1: scan
../../bin/df-init --scan | jq .

# Step 6 simulation: read mock response
# (In real skill use, the skill reads DEVFLOW_AI_MOCK=1 and uses the fixture)
# Build a mock patch from the fixture
FIXTURE="../../tests/fixtures/ai-responses/df-init-response.json"
SHA=$(git rev-parse HEAD)
PATCH=$(jq -n \
  --arg sha "$SHA" \
  --argjson fixture "$(cat $FIXTURE)" \
  '{
    config: {
      service: "sample-repo", workspace: null, stack: "dotnet-9",
      test_cmd: "dotnet test", last_synced: $sha, schema_version: 1,
      node_types: { custom: [] },
      edge_staleness_threshold: 30,
      edge_rel_types: { builtin: ["depends_on","uses","persisted_in","implements","emits","handles"], custom: [] },
      graph_limits: { max_nodes: 2000, max_edges: 10000, prune_min_age_commits: 90 },
      classifiers: {}
    },
    memory: {
      schema_version: 1, last_synced: $sha,
      stack: $fixture.call2.stack,
      architecture: $fixture.call2.architecture,
      conventions: $fixture.call2.conventions
    },
    nodes: {
      schema_version: 1,
      nodes: ($fixture.call1 | map(select(.type != "unclassified") | {
        id: (.type + ":" + (.file | gsub("/"; ".") | sub("\\.[^.]+$"; ""))),
        name: (.file | split("/") | last | sub("\\.[^.]+$"; "")),
        type: .type, file: .file, intent: .intent, confidence: .confidence, last_seen_sha: $sha
      }))
    },
    edges: { schema_version: 1, edges: [] }
  }')

echo "$PATCH" | ../../bin/df-init --write-memory
```

Expected: Exits 0.

- [ ] **Step 4: Verify all files exist and are valid JSON**

```bash
# Still in tests/fixtures/sample-repo
jq . .devflow/config.json
cat .devflow/active/memory.md
ls -la .devflow/branches/
cat .git/hooks/post-commit
cat .git/hooks/post-checkout
```

Expected:
- `config.json` parses as JSON with `dirty: false`
- `memory.md` shows graph nodes
- `branches/` contains one directory for the current branch
- Both hooks contain `df-sync`

- [ ] **Step 5: Clean up test repo state**

```bash
cd tests/fixtures/sample-repo && rm -rf .devflow
```

- [ ] **Step 6: Commit final state**

```bash
git add .
git commit -m "feat: complete vertical-1 df-init + init skill — all tests pass, shellcheck clean"
```

---

## Definition of Done Checklist

- [ ] `bin/df-init` exists and is executable
- [ ] `skills/init/SKILL.md` exists
- [ ] `bats tests/df-init.bats` — ALL categories pass
- [ ] `shellcheck bin/df-init` — no errors
- [ ] End-to-end mock run on sample-repo fixture passes
- [ ] `DEVFLOW_AI_MOCK=1` path documented in skill
