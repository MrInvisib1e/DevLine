# /df-init — Initialize DevFlow

Initialize DevFlow memory for the current project (or workspace in orchestrator mode).

## When to Use
Run once when starting work in a new repository. Re-run after major structural changes.

## Pre-flight
- Verify `codebase-memory-mcp` is available: `command -v codebase-memory-mcp`
- If not found: T2 Inform — "codebase-memory-mcp not found. Run `df-install --mcp` first."
- Check if `.devflow/` already exists in current dir or git root

## Workflow

### Step 1 — Detect project boundaries (T1 Silent)

Run: `df-init --scan`

Returns: `{project_root, git_root, stack}`

Rules:
- `.devflow/` in current dir → use it (scoped project)
- `.devflow/` at git root → use git root
- Neither → create `.devflow/` in current directory
- NEVER go above git root

### Step 2 — Index and generate memory (T1 Silent)

Run: `df-init --write-memory`

This calls `index_repository` via codebase-memory-mcp, then `get_architecture`, then renders `.devflow/memory.md`.

### Step 3 — Final summary (T3 Gate)

Present:
```
DevFlow initialized at .devflow/
Stack: {runtime} / {frontend}
Project: {service}
Memory: {N} nodes indexed

[A] Continue  [B] Show memory.md  [C] Abort
```

Wait for user input before proceeding.

### Step 4 — Install hooks (T1 Silent)

Install post-commit hook:
```bash
cp ~/.devflow/hooks/post-commit .git/hooks/post-commit
chmod +x .git/hooks/post-commit
```

T2 Inform: "Post-commit hook installed — memory updates automatically after each commit."

## Orchestrator Mode

Run `/df-init --orchestrator` from a monorepo root to bind multiple subproject `.devflow/` directories into an orchestrator config.

Requirements: each subproject must be initialized first (`/df-init` in each folder).

Then reference each project using `--project <name>` in df-explain queries.

## Freshness

Memory is regenerated automatically on commit. To force refresh: `/df-sync`

## Error Reference

| Code | Trigger | Action |
|------|---------|--------|
| E01 | Not inside a git repository | HALT — "df-init requires a git repository" |
| E02 | codebase-memory-mcp not found | HALT — "Run `df-install --mcp` first" |
| E03 | Indexing fails | HALT — "codebase-memory-mcp indexing failed. Check if server is running." |
