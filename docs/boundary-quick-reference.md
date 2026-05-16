# DevFlow Project Boundaries — Quick Reference

## TL;DR

**DevFlow = single-project system per git repo**

- Project boundary = `git rev-parse --show-toplevel`
- `.devflow/` location = `${GIT_ROOT}/.devflow/`
- All files scoped by: git root + branch
- Monorepo? Each subproject needs separate git repo or manual workspace registration

---

## Core Components & Boundaries

### 1. df-init —  Project Detection

```bash
# Finds project root via:
git rev-parse --show-toplevel

# Scans ALL tracked files:
git ls-files

# Stack detection: "last match wins"
# If repo has both package.json AND go.mod → last found wins
```

**Config stored:** `.devflow/config.json` at git root

**Workspace field:** `null` (metadata, unused)

---

### 2. df-sync — Per-Branch Memory

```bash
# Branch-specific memory at:
.devflow/branches/<canonicalized-branch>/
  memory.json
  nodes.json
  edges.json
  
# Active branch symlink:
.devflow/active -> branches/feature__name

# One graph database per git repo:
.devflow/graph.db
```

---

### 3. df-workspace — Cross-Project Registry

```bash
# Workspace registry (user-scoped):
~/.devflow/workspaces/<workspace-name>.json

# Register sibling:
df-workspace add myapp backend /path/to/service-b

# Read sibling's memory (one-way):
df-workspace read myapp backend memory.json

# No automatic discovery or sharing
```

---

### 4. Stack Detection Markers

**Global rules apply to entire repo:**

```
package.json          → runtime: nodejs
*.csproj / *.sln      → runtime: dotnet-9
go.mod                → runtime: go
Cargo.toml            → runtime: rust
vite.config.*         → frontend: sveltekit
next.config.*         → frontend: nextjs
```

**Monorepo problem:** If root has `package.json` AND subproject has `go.mod`, last match wins.

---

### 5. File Classification Rules

**Applied to all files in repo (no sub-scoping):**

```
*.test.*, *.spec.*       → test
*.config.*, .eslintrc*   → config
*.md, docs/**            → docs
Dockerfile, .github/**   → infra
*.sql, migrations/**     → data
package.json, *.lock     → deps
bin/**, scripts/**, *.sh → script
everything else          → source
```

**No per-subproject overrides available.**

---

## Scope References by File

| Component | Scope | Location | Hard Boundary |
|-----------|-------|----------|---------------|
| Configuration | Per-git-root | `.devflow/config.json` | ✅ git root |
| Memory | Per-branch | `.devflow/branches/<branch>/` | ✅ branch |
| Graph | Per-git-root | `.devflow/graph.db` | ✅ git root |
| Worktrees | Per-git-root | `.devflow/worktrees/` | ✅ git root |
| Plans | Per-git-root | `.devflow/plans/` | ✅ git root |
| Workspace registry | User | `~/.devflow/workspaces/` | ⚠️ global, not repo-scoped |

---

## Git Root Detection (All Scripts)

Every DevFlow script starts with:

```bash
git rev-parse --is-inside-work-tree  # ← Checks if inside git repo
```

If true: uses `git rev-parse --show-toplevel` to find boundary.

**Files affected:**
- `df-init` (lines 22, 76, 79, 217, 293, 450)
- `df-sync` (lines 15, 375, 707, 713, 953, 985)
- `df-explain` (lines 15, 76, 126, 139)
- `df-export` (lines 13, 127, 157, 183)
- `df-resolve` (lines 13, 37)
- `df-workspace` (lines 22, 149, 167)
- `df-test` (lines 13, 72, 124)

---

## Monorepo Scenarios

### ❌ npm Workspaces at Root

```
my-monorepo/
  package.json (workspaces: [...])
  apps/web/     → Separate frontend stack
  apps/api/     → Separate backend stack
```

**Result:** Treated as single project with merged stack detection.

### ❌ Lerna/pnpm Monorepo

```
my-monorepo/
  pnpm-workspace.yaml
  packages/ui/
  packages/api/
```

**Result:** Single `.devflow/` at root scanning all packages.

### ✅ Separate Git Repos (Recommended)

```
services/
  service-a/.git/
    .devflow/
  service-b/.git/
    .devflow/
```

**Use `df-workspace` to link them:**

```bash
# In service-a:
df-workspace add platform backend /path/to/service-b
df-workspace read platform backend memory.json
```

---

## Config File Fields Related to Scope

### `.devflow/config.json`

```json
{
  "service": "project-name",           // Just metadata, no scoping
  "workspace": null,                   // Unused; no scoping effect
  "stack": {
    "runtime": "nodejs",               // Repo-wide, no override per subproject
    "frontend": null,
    "test_cmd": "npm test"             // Global test command
  },
  "graph_limits": {
    "max_nodes": 500,                  // Applied to entire .devflow/graph.db
    "max_files_per_sync": 200
  },
  "classifiers": [],                   // Currently empty; no custom rules
  "edge_rel_types": [                  // Global relationship types
    "depends_on", "uses", "persisted_in", "implements", "emits", "handles"
  ]
}
```

**None of these fields can partition scope within a git repo.**

---

## Skills & Project Assumptions

All skills assume:
1. One `.devflow/` directory exists at git root
2. `.devflow/` is writable and fully initialized
3. All files in scope are under git root (no subproject filtering)
4. Stack detection is repo-wide

| Skill | Check | Behavior |
|-------|-------|----------|
| `/init` | `[ -d .devflow/ ]` | Creates/updates `.devflow/` at git root |
| `/feature` | `[ -d .devflow/ ]` && `[ -L .devflow/active ]` | Assumes single-project feature context |
| `/fix` | `[ -f .devflow/config.json ]` | Reads config; no subproject override |
| `/review` | `[ -f .devflow/active/memory.md ]` | Reviews entire project memory |
| `/plan` | `[ -d .devflow/ ]` | Plans for full repo scope |

---

## No Support For

- ❌ Multiple `.devflow/` directories per git repo
- ❌ Per-subproject stack detection override
- ❌ Per-subdirectory classifier rules
- ❌ Shared graph database across projects
- ❌ Automatic monorepo workspace discovery
- ❌ Parent/child `.devflow/` hierarchy
- ❌ Custom project boundary markers
- ❌ Cross-project memory synchronization

---

## If You Need Monorepo Support

**Option 1: Separate Git Repos (Recommended)**
- Each subproject as standalone git repo
- Use `df-workspace` for cross-project context

**Option 2: Manual Workspace Registration**
- Initialize full monorepo as single project
- Register subprojects via `df-workspace add`
- Read sibling memory when needed
- Accept merged stack detection

**Option 3: Wait for Future Enhancement**
- Add `project_scope` field to config
- Extend graph schema with `project_id` column
- Implement per-subproject classifier rules

---

## Reference Documents

- **Full Analysis:** `docs/devflow-boundary-analysis.md`
- **init Skill:** `skills/init/SKILL.md` (stack detection, workspace derivation)
- **df-workspace Script:** `bin/df-workspace` (registry management)
- **df-init Script:** `bin/df-init` (git root detection, file enumeration)
