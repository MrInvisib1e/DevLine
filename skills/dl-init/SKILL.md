# /dl-init — Initialize Devline

Initialize Devline memory for the current project (or workspace in orchestrator mode).

## When to Use
Run once when starting work in a new repository. Re-run after major structural changes.

## Pre-flight
- Verify `codebase-memory-mcp` is available: `command -v codebase-memory-mcp`
- If not found: T2 Inform — "codebase-memory-mcp not found. Run `dl-install --mcp` first."
- Check if `.devline/` already exists in current dir or git root

## Workflow

### Step 1 — Detect project boundaries (T1 Silent)

Run: `dl-init --scan`

Returns: `{project_root, git_root, stack}`

Rules:
- `.devline/` in current dir → use it (scoped project)
- `.devline/` at git root → use git root
- Neither → create `.devline/` in current directory
- NEVER go above git root

### Step 2 — Index and generate memory (T1 Silent)

Run: `dl-init --write-memory`

This calls `index_repository` via codebase-memory-mcp, then `get_architecture`, then renders `.devline/memory.md`.

### Step 3 — Final summary (T3 Gate)

Present:
```
Devline initialized at .devline/
Stack: {runtime} / {frontend}
Project: {service}
Memory: {N} nodes indexed

[A] Continue  [B] Show memory.md  [C] Abort
```

Wait for user input before proceeding.

### Step 4 — Install hooks (T1 Silent)

Install git hooks:
```bash
cp ~/.devline/hooks/post-commit .git/hooks/post-commit
cp ~/.devline/hooks/post-checkout .git/hooks/post-checkout
chmod +x .git/hooks/post-commit .git/hooks/post-checkout
```

T2 Inform: "Hooks installed — memory updates on commit and branch switch."

## Orchestrator Mode

Run `/dl-init --orchestrator` from a monorepo root to bind multiple subproject `.devline/` directories into an orchestrator config.

Requirements: each subproject must be initialized first (`/dl-init` in each folder).

Then reference each project using `--project <name>` in dl-explain queries.

## Freshness

Memory is regenerated automatically on commit. To force refresh: `/dl-sync`

## Error Reference

| Code | Trigger | Action |
|------|---------|--------|
| E01 | Not inside a git repository | HALT — "dl-init requires a git repository" |
| E02 | codebase-memory-mcp not found | HALT — "Run `dl-install --mcp` first" |
| E03 | Indexing fails | HALT — "codebase-memory-mcp indexing failed. Check if server is running." |
