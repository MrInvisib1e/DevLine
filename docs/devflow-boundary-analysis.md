# DevFlow Project Boundary Analysis

## Executive Summary

DevFlow **currently operates on a single-project model**, with project boundaries strictly defined by the git repository root. There is **minimal support for monorepos or multi-project scenarios**. The system is designed around:

- **One `.devflow/` directory per git repo** — at the git root
- **One workspace name** (optional, in config) — but not used for project separation
- **Git root as the project boundary** — determined via `git rev-parse --show-toplevel`
- **Workspace registry for adjacent services** — but cross-project memory sharing is limited

---

## 1. Project Root Detection

### How DevFlow Determines Project Root

**Primary Method: Git Root (All Scripts)**

Every script uses `git rev-parse --show-toplevel` to find the project boundary:

- **df-init** (line 22, 76, 79, 217, 293, 450): Checks `git rev-parse --is-inside-work-tree`
- **df-sync** (line 15, 375, 707, 713, 953, 985, 1031): Same check
- **df-explain** (line 15, 76, 126, 139): Uses `git rev-parse --show-toplevel` to locate `.devflow/`
- **df-export** (line 13, 127, 157, 183): Finds project via git root
- **df-resolve** (line 13, 37): Uses `git rev-parse --show-toplevel`
- **df-workspace** (line 22, 149, 167): Checks git repo + uses root for worktree paths
- **df-test** (line 13, 72, 124): Verifies inside git repo
- **df-install** (line 107-121): Locates DevFlow root (different purpose — app root, not project root)

**File Paths Used:**
```
${GIT_ROOT}/.devflow/                      # All DevFlow state
${GIT_ROOT}/.devflow/config.json          # Project configuration
${GIT_ROOT}/.devflow/branches/            # Per-branch memory
${GIT_ROOT}/.devflow/active/              # Symlink to active branch
${GIT_ROOT}/.devflow/graph.db             # SQLite knowledge graph
${GIT_ROOT}/.devflow/worktrees/           # Git worktree storage
${GIT_ROOT}/.devflow/plans/               # Feature plans (feature skill)
```

### No Markers for Monorepo Root Detection

DevFlow does **NOT** look for:
- `pnpm-workspace.yaml` / `npm workspaces` config
- `lerna.json`
- `rushrc.js` / Rush config
- Custom `.devflow-root` marker
- Parent directory `.devflow/` (to skip subproject repos)
- `packages/*/` or `services/*/` patterns

**Result:** Each git repo, including monorepo subprojects, gets its own `.devflow/` directory.

---

## 2. Configuration Structure

### `.devflow/config.json` Schema

**File:** `/Volumes/ReydoSSD/SourceCode/Development-Flow/.devflow/config.json`

```json
{
  "service": "DevFlow",
  "workspace": null,  // ← Currently unused for project separation
  "stack": {
    "runtime": "nodejs",
    "frontend": null,
    "test_cmd": "bats tests/"
  },
  "last_synced": "53743f26beae35f5634a82a6a201d340ed34e09d",
  "schema_version": 1,
  "node_types": {
    "custom": []
  },
  "edge_staleness_threshold": 10,
  "edge_rel_types": [
    "depends_on",
    "uses",
    "persisted_in",
    "implements",
    "emits",
    "handles"
  ],
  "graph_limits": {
    "max_nodes": 500,
    "prune_min_age_commits": 5,
    "max_files_per_sync": 200
  },
  "classifiers": [],
  "dirty": false
}
```

### Key Fields for Boundaries

| Field | Purpose | Current Use | Monorepo Support |
|-------|---------|-------------|------------------|
| `service` | Project name | Directory name | ❌ No scope control |
| `workspace` | Workspace identifier | Derived from git remote | ⚠️ Null/unused for separation |
| `stack.*` | Runtime/frontend stack | Stack detection only | ❌ No sub-project override |
| `graph_limits` | Memory constraints | Per-project defaults | ❌ Applied globally to `.devflow/` |
| `classifiers` | Custom file types | Project-wide | ❌ No per-subproject rules |

**Analysis:** The `workspace` field exists but is set to `null` and never used to enforce boundaries. Graph limits are per-project but apply to the entire `.devflow/` scope.

---

## 3. Stack Detection (How Monorepos Look)

### init/SKILL.md — Stack Detection Rules (Lines 58–71)

DevFlow infers stack by looking for markers in **all tracked files**:

```
| Signal | Inferred |
|--------|----------|
| package.json present | runtime: nodejs |
| package.json + vite.config.* | frontend: sveltekit |
| *.csproj or *.sln | runtime: dotnet-9 |
| go.mod | runtime: go |
| Cargo.toml | runtime: rust |
```

**In a Monorepo:** If the root has `package.json` (monorepo root) AND subprojects have `*.csproj` files, DevFlow will infer **both nodejs and dotnet-9**, which is incorrect.

**Current Behavior (df-init --scan, lines 116–124):**
```bash
for f in "${stack_hints_files[@]}"; do
  case "$f" in
    Program.cs|Startup.cs|*.csproj|*.sln) inferred_runtime="dotnet-9" ;;
    vite.config.ts|vite.config.js) inferred_frontend="sveltekit" ;;
  esac
done
```

Result: **Last match wins.** If both markers exist, only the last-detected stack survives.

---

## 4. Workspace Registry — Limited Multi-Project Support

### df-workspace — The Only Multi-Project Tool

**File:** `/Volumes/ReydoSSD/SourceCode/Development-Flow/bin/df-workspace`

**Purpose:** Maintain a registry of sibling projects for cross-project memory reading.

**Structure:**
```
~/.devflow/workspaces/
  <workspace-name>.json          # Registry file
    service-1: /path/to/service-1
    service-2: /path/to/service-2
    ...
```

**Commands:**
```bash
df-workspace add <workspace> <service> <path>      # Register a service
df-workspace list                                   # List workspaces
df-workspace read <workspace> <service> <memory>   # Read sibling's memory
df-workspace create <branch>                       # Create git worktree
df-workspace worktree-remove <branch>              # Remove worktree
```

**Key Limitations (Lines 113–142):**

1. **Read-only cross-project access:**
   ```bash
   local sibling_path
   sibling_path=$(jq -r --arg svc "$service" '.[$svc] // empty' "$reg")
   if [[ ! -d "$sibling_path/.devflow" ]]; then
     err "Sibling \"$service\" has no .devflow/ directory. Run df-init in that repo first."
     exit 1
   fi
   local target_file="${sibling_path}/.devflow/active/${memory_file}"
   cat "$target_file"
   ```

2. **Each service must have its own initialized `.devflow/`** — no shared memory store.

3. **Registry is global** (`~/.devflow/workspaces/`), not per-repo — workspace definitions are user-scoped, not project-scoped.

4. **Memory reading is one-way:** Only allows reading sibling memory into current context; does not sync or merge.

**Example Usage (Inferred from Code):**
```bash
# In service-a repo:
df-workspace add myapp backend /path/to/service-b
df-workspace add myapp frontend /path/to/service-c

# Later, read service-b's memory:
df-workspace read myapp backend memory.json > /tmp/backend-memory.json
```

---

## 5. Git Root as Boundary — Evidence

### Every Script Enforces Git Root

**df-init --scan (Line 84–86):**
```bash
# Enumerate all tracked files
local all_files
mapfile -t all_files < <(git ls-files)
```
Scope: **All files tracked in git** (no filter by subdirectory).

**df-sync (Line 375–713):**
```bash
head_sha=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
```
Scope: **Current branch only** — no per-subproject tracking.

**df-explain --diff (Line 121–149):**
```bash
nodes_path=".devflow/branches/${branch_canon}/nodes.json"
nodes_at_sha1=$(git show "${sha1}:${nodes_path}" 2>/dev/null | jq '[.nodes[].id]' 2>/dev/null || echo "[]")
```
Scope: **Git history** — reads `.devflow/branches/` from any commit.

**Result:** DevFlow treats the entire git repository as a single project. Subprojects in monorepos get no special treatment.

---

## 6. File Classification — No Per-Subproject Rules

### init/SKILL.md — Auto-Classifier (Lines 43–54)

```
| Pattern | Node Type |
|---------|-----------|
| *.test.*, *.spec.*, __tests__/** | test |
| *.config.*, *.env*, .eslintrc*, tsconfig*, vite.config*, jest.config* | config |
| *.md, *.mdx, docs/** | docs |
| Dockerfile, docker-compose*, .github/**/*.yml | infra |
| *.sql, migrations/**, **/migrations/** | data |
| package.json, *.lock, go.mod, requirements.txt | deps |
| bin/**, scripts/**, Makefile, *.sh | script |
| Everything else | source |
```

**Global rules only** — no way to define project-specific classifiers that vary by subproject path.

**config.json field (Line 28):**
```json
"classifiers": []
```
Currently unused. No mechanism to apply different rules to `apps/web/` vs `packages/api/`.

---

## 7. Memory Scope — Per-Branch, Per-Git-Root

### Branch-Based Memory Isolation

**df-init --write-memory (Lines 295–401):**

```bash
local branch
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
local branch_canon
branch_canon=$(canonicalize_branch "$branch")

local devflow_dir=".devflow"
local branch_dir="${devflow_dir}/branches/${branch_canon}"
```

**Structure:**
```
.devflow/
  branches/
    main/
      memory.json
      nodes.json
      edges.json
      memory.md
    feature__foo/
      memory.json
      nodes.json
      edges.json
      memory.md
  active -> branches/feature__foo  # Symlink to current branch
```

**Isolation Mechanism:**
- **Per-branch:** Each branch has separate memory (`branches/<canonicalized-branch>/`)
- **Per-git-root:** Only one `.devflow/` per git repository
- **No per-subproject:** All branches in a monorepo subproject share the same `.devflow/`

---

## 8. Monorepo Scenarios — Current Limitations

### Scenario 1: Monorepo with npm Workspaces

```
my-monorepo/
  package.json (workspaces: [...])
  apps/
    web/
      package.json (frontend: sveltekit)
    api/
      package.json (backend: nodejs)
  packages/
    ui/
      package.json (library)
```

**Current behavior:**
- `df-init` at monorepo root scans all files under git
- Detects `package.json` everywhere → infers `runtime: nodejs`
- Detects `vite.config.ts` in `apps/web/` → infers `frontend: sveltekit`
- **Result:** Treats monorepo as single project with "nodejs + sveltekit" stack
- **Problem:** Subproject-specific stacks (e.g., `api/` is Node.js microservice) are not represented
- **No way to:** Ask "which slice file belongs to `apps/web/`?" vs `packages/ui/`

### Scenario 2: Monorepo with .NET Subprojects

```
my-monorepo/
  .git/
  apps/
    service-a/
      service-a.csproj
  services/
    service-b/
      service-b.csproj
```

**Current behavior:**
- `df-init --scan` finds both `.csproj` files
- Last match wins: `inferred_runtime="dotnet-9"`
- **Result:** Single `.devflow/config.json` with `runtime: dotnet-9` for the entire repo
- **Problem:** No distinction between service-a and service-b; both treated as one project

### Scenario 3: Monorepo with Mixed Stacks

```
my-monorepo/
  frontend/
    package.json + vite.config.ts
  backend/
    go.mod
  scripts/
    Makefile
```

**Current behavior:**
- Detects: nodejs, sveltekit, go
- Last match wins again
- **Result:** `runtime: go, frontend: sveltekit` (incorrect for most of the repo)

---

## 9. Workspace Field — Defined but Unused

### init/SKILL.md — Workspace Derivation (Lines 70–71, 319, 331)

```
| Signal | Derived name |
|--------|-------------|
| git remote get-url origin | workspace name (strip host/org, use repo name) |
| No remote | workspace name = basename of git root directory |
```

**Current State in config.json:**
```json
"workspace": null
```

**Usage in Skills:**
- **init/SKILL.md** (Line 201): Includes `workspace` field in config patch JSON
- **No skill** uses it to enforce project boundaries
- **No script** uses it to determine scope

**Conclusion:** `workspace` is **metadata only** — does not affect how memory is scoped, classified, or shared.

---

## 10. Features That Assume Single Project

### Feature Skill — Assumes One Project Context

**feature/SKILL.md (Lines 45–64):**
```bash
which df-init && test -d .devflow/
# If .devflow/ does not exist: HALT — "Run `/init` first"

test -L .devflow/active && ls .devflow/active/
# If symlink missing: HALT — "Run `/init` — no active branch symlink found"
```

**Worktrees stored at git root:**
```bash
local root
root="$(git rev-parse --show-toplevel)"
local worktree_path="${root}/.devflow/worktrees/${branch}"
```
(df-workspace, lines 149–150, 167–168)

**Result:** Feature implementation assumes:
- One `.devflow/` per repo
- One active branch symlink
- Worktrees created under `.devflow/worktrees/` at git root
- No per-subproject feature isolation

### Plan Skill — Same Assumption

**plan/SKILL.md (Lines 31–44):**
```bash
which df-init && ls .devflow/memory/ 2>/dev/null

if `.devflow/` does not exist: HALT — "Run `/init` first"
```

Write location: `.devflow/plans/YYYY-MM-DD-<slug>/plan.md`

### Review Skill — Same Assumption

**review/SKILL.md (Lines 43–62):**
```bash
ls .devflow/active/memory.md 2>/dev/null
# Degraded mode if .devflow/ is absent
```

---

## 11. Graph Database — Single Scope

### SQLite Graph Store (df-init, df-sync, df-explain)

**Location:**
```
.devflow/graph.db    # Single database per git root
```

**Schema (df-init, lines 307–327):**
```sql
CREATE TABLE IF NOT EXISTS nodes (
  id      TEXT PRIMARY KEY,
  kind    TEXT NOT NULL DEFAULT "source",
  name    TEXT NOT NULL DEFAULT "",
  file_id TEXT NOT NULL DEFAULT "",
  line    INTEGER DEFAULT 0,
  col     INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS edges (
  source     TEXT NOT NULL,
  target     TEXT NOT NULL,
  kind       TEXT NOT NULL DEFAULT "uses",
  confidence REAL NOT NULL DEFAULT 0.7,
  PRIMARY KEY (source, target, kind)
);
```

**Constraints:**
- No `project_id` or `subproject` column
- File IDs are relative paths from git root (no scoping)
- `graph_limits` in config apply globally to the entire `.devflow/`

**Result:** All nodes and edges for all files in the git repo share one graph database.

---

## 12. Cross-Project Memory — No Native Support

### df-workspace --read (Lines 113–142)

Only way to access another project's memory:

```bash
cmd_read() {
  local workspace="$1" service="$2" memory_file="$3"
  # ...
  local sibling_path
  sibling_path=$(jq -r --arg svc "$service" '.[$svc] // empty' "$reg")
  if [[ ! -d "$sibling_path/.devflow" ]]; then
    err "Sibling \"$service\" has no .devflow/"
    exit 1
  fi
  local target_file="${sibling_path}/.devflow/active/${memory_file}"
  cat "$target_file"
}
```

**Limitations:**
1. **Manual registration required** — must run `df-workspace add` for each sibling
2. **Must be initialized separately** — each repo needs its own `/init`
3. **Read-only** — no shared or merged memory store
4. **At user scope** — registry is `~/.devflow/workspaces/`, not per-repo
5. **No automatic discovery** — monorepo packages are not auto-registered

---

## 13. Summary of Project Boundary Mechanisms

| Mechanism | Type | Scope | Monorepo Support |
|-----------|------|-------|------------------|
| Git root (`git rev-parse --show-toplevel`) | Hard boundary | Per-repo | ❌ Each subproject gets own `.devflow/` |
| `.devflow/` directory | Hard boundary | Git root | ❌ No parent-child relationship |
| Branch canonicalization | Isolation | Per-branch | ⚠️ Works but doesn't help across repos |
| `workspace` field | Metadata | User scope | ❌ Unused; not project-scoped |
| `graph_limits` | Soft limit | Single database | ❌ Applied to entire repo |
| File classifier rules | Global rules | Per-project | ❌ No per-subproject overrides |
| `df-workspace` registry | External registry | User scope | ⚠️ Manual, read-only, not automatic |

---

## Key Files and Line References

| File | Key Lines | Purpose |
|------|-----------|---------|
| `bin/df-init` | 22, 76, 79, 84–86, 217, 293, 450 | Git root detection, file enumeration |
| `bin/df-sync` | 15, 375, 707, 713, 953, 985, 1031 | Scope to current branch & git root |
| `bin/df-explain` | 15, 76, 126, 139 | Git root for `.devflow/` location |
| `bin/df-workspace` | 7–8, 40–42, 113–142, 149, 167 | Workspace registry; sibling access |
| `bin/df-export` | 13, 127, 132, 157, 183 | Project root via git |
| `bin/df-resolve` | 13, 37, 38 | Active memory location |
| `skills/init/SKILL.md` | 58–71, 70–71, 85, 201, 319, 331 | Stack detection, workspace derivation |
| `skills/feature/SKILL.md` | 45–64, 121, 199 | Project boundary assumptions |
| `.devflow/config.json` | All | Config structure; `workspace: null` |
| `.devflow/` directory | Root structure | Single per git repo |

---

## Recommendations for Monorepo Support (If Needed)

If DevFlow needs to support monorepos in the future:

1. **Add `project_scope` to config.json**
   - Define which subdirectory (e.g., `apps/web/`, `packages/api/`) this `.devflow/` manages
   - Or allow multiple `.devflow/` directories per git repo

2. **Extend graph schema**
   - Add `project_id` column to track which subproject owns each node
   - Or create separate graph databases per project

3. **Enhance file classification**
   - Allow per-subproject classifier rules in config
   - Or read from `<subproject>/.devflowrc` or similar

4. **Auto-discover workspace registry**
   - Scan for `package.json` with `"workspaces"` or `pnpm-workspace.yaml`
   - Auto-register sibling projects at init time

5. **Support shared memory location**
   - Option to store `.devflow/` at monorepo root and scope by subdirectory
   - Or implement a "parent .devflow/" fallback mechanism

---

## Conclusion

**DevFlow is fundamentally a single-project system.** Project boundaries are:
- **Hard-coded** to the git repository root via `git rev-parse --show-toplevel`
- **Immutable** — all `.devflow/` files are scoped to that root
- **All-or-nothing** — stack detection, file classification, memory, and graph are repo-wide

The `workspace` field exists for future extensibility but is currently unused. The `df-workspace` registry allows **reading** sibling project memory for context, but does not enforce boundaries or unify scopes.

**For monorepos:** Each subproject should have its own git repository, or DevFlow would require significant architectural changes to support sub-repository project scoping.
