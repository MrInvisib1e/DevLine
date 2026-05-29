---
name: devline-explain
description: Use when a developer needs to understand what a feature, file, or module does and why it exists, grounded in actual source files.
requires: []
requires_if:
  dl-sync: memory_stale
triggers_on_complete: []
---

# /dl-explain — Business Logic Explanation

Explain what code does and *why* it exists, grounded in actual source files and project memory.

**Invoked as:**
- `/dl-explain <feature or concept>` — explain a feature by name or topic
- `/dl-explain --file <path>` — explain a specific file or module
- `/dl-explain` (no args) — high-level overview of the whole application

<iron-law>
Load `skills/_shared.md` before proceeding. T1/T2/T3 tiers and SIF rules are defined there.
EXPLAIN ONLY. This skill never writes, modifies, or suggests code changes.
</iron-law>

---

## Pre-Flight (T1 Silent)

Run: `dl-log skill_start --skill dl-explain 2>/dev/null || true`

1. Check `.devline/` exists — if not: `HALT. Print exactly: "Run /dl-init first to initialize Devline."`
2. **Memory freshness:** Apply the Pre-Flight Staleness Check defined in `skills/_shared.md`.

---

## Step 1: Routing & Scope Detection (T2 Inform)

| Invocation | Scope | What to gather |
|-----------|-------|---------------|
| `/dl-explain` (no args) | `app` | `memory.md` architecture + top-level README |
| `/dl-explain --file <path>` | `file` | The specified file directly |
| Query < 3 chars | `app` | `memory.md` architecture + top-level README — T2 Inform: "Query too short — showing app overview." |
| Query = "everything" / "all" / "app" | `app` | `memory.md` architecture + top-level README |
| Query matches a file path pattern (`*.ts`, `/src/...`) | `file` | The matched file directly |
| `/dl-explain <query>` (named concept or domain term) | `feature` | Graph + memory + relevant source files |
| DEFAULT | `feature` | Graph + memory + relevant source files |

Print: `[Devline] Explaining: <query> (scope: <app|file|feature>)`

---

## Step 2: Context Gathering

### 2a. Read memory (T1 Silent — fallback on failure)

```bash
cat .devline/memory.md
```

| Result | Action |
|--------|--------|
| File exists | Read it — use architecture and domain sections |
| File missing | T2 Warn: "[Devline] memory.md not found — using code-only analysis." Continue. |
| DEFAULT | Continue |

### 2b. Structural search (T2 Inform)

For `feature` or `file` scope:

**Schema probe (T1 Silent):** Before searching, call `get_graph_schema` via the binary to determine available node labels:

```bash
dl-explain --schema
```

If `Function` nodes are absent but `Section` nodes exist (common in bash/markdown repos), bias all subsequent searches toward `label:Section`.

**Four-tier fallback search:**

| Tier | Command | Advance when |
|------|---------|-------------|
| 1 | `dl-explain <query>` (structural graph search) | 0 results |
| 2 | `dl-explain <query>` with explicit `label:Section` | 0 results |
| 3 | `search_code` via MCP (content/grep-style search) | 0 results |
| 4 | `grep -r <query> . --include="*.ts" --include="*.js" --include="*.py" --include="*.md" -l` | last resort |

| Result | Action |
|--------|--------|
| Symbols found at any tier | Note file paths and relationships |
| All tiers return 0 | T2 Warn + HALT with E-NF message |
| DEFAULT | Continue with found results |

### 2c. Read source files

<scope>
READ: up to 5 files identified by the graph or file search. DO NOT read entire directories. DO NOT suggest code changes, refactors, or improvements — this skill explains only.
</scope>

| File size | What to read |
|-----------|-------------|
| ≤ 300 lines | Read completely via `Read` tool |
| > 300 lines | Use `dl-explain --snippet <file> <start> <end>` to read only the relevant region identified by search. Saves ~80% token cost vs full file read. Locate entry points first via `grep -n "export\|function\|class\|def " <file>`, then snippet those regions. |
| DEFAULT | Read completely |

If nothing is found after both graph search and grep:

| Condition | Action |
|-----------|--------|
| No files found | HALT. Print exactly: "Couldn't find anything related to '<query>' in this codebase." |
| 1–5 files found | Proceed to Step 3 |
| >5 files found | Pick the 5 most central (highest degree or closest name match) |
| DEFAULT | Proceed with what was found |

CHECKPOINT: "[Devline] Context gathered: N files read, graph: <found|fallback|failed>"

---

## Step 3: Generate Explanation

Present the explanation in this exact format:

```
## Explanation: <query>

**Scope:** <app | file | feature>

### Purpose
[What this does and why it exists — the business motivation, not just the implementation.
Answer: "What problem does this solve for the user / system?"]

### How it works
[Step-by-step description of the execution flow, grounded in actual code.
Reference real function names, files, and data transformations.
Use a numbered list if there are sequential steps.]

### Key files
| File | Role |
|------|------|
| path/to/file | What this file contributes |

### Edge cases & constraints
[Known limits, error paths, unusual behavior, or important invariants.
If none found: "No notable edge cases identified."]
```

**Quality rules:**

| Rule | Why |
|------|-----|
| Reference real identifiers | Generic descriptions are useless — name the actual functions and files |
| Business motivation first | Start with *why*, not *what* |
| Scope to the query | Don't pad with unrelated context |
| No code suggestions | This skill explains, it does not recommend changes |
| No "I think" or "probably" | Only state what you can verify from the files read |

---

## Scope-Specific Guidance

### App-level (`scope: app`)

Use `memory.md`'s architecture section as the backbone. Cover:
1. What the application does (user-facing purpose)
2. Major domains / modules and their responsibilities
3. How they interact (data flow between layers)
4. Key external dependencies

### File-level (`scope: file`)

Explain:
1. What problem this file solves
2. Its public interface (exports, key functions/classes)
3. What it depends on and what depends on it
4. Notable implementation details or constraints

### Feature-level (`scope: feature`)

Explain:
1. User-facing behavior this feature enables
2. Entry points (API endpoints, CLI commands, UI components)
3. Data flow from entry to storage/output
4. Business rules enforced in the code

---

## Rationalization Prevention

| Temptation | Reality |
|-----------|---------|
| "I'll explain from memory without reading files" | Explanations without file evidence are hallucinations. Read first. |
| "The query is vague, I'll explain everything" | Scope to app-level. Don't dump the whole codebase. |
| "I found one file, that's enough" | Read up to 5. Call paths and dependencies matter. |
| "While explaining, I'll suggest a refactor" | This skill explains. `/dl-fix` or `/dl-feature` handles changes. |
| "memory.md says X, the code says Y — I'll go with memory" | Trust the code. Memory may be stale. State the discrepancy. |

---

CHECKPOINT: "[Devline] Explanation delivered for: <query>"

Run: `dl-log skill_end --skill dl-explain 2>/dev/null || true`

---

## Error Reference

| Code | Trigger | Action |
|------|---------|--------|
| E01 | `.devline/` missing | `HALT. Print exactly: "Run /dl-init first to initialize Devline."` |
| E13 | `dl-explain` binary fails | T2 Warn, fall back to grep-based file search |
| E-NF | No files found for query | Print exactly: "Couldn't find anything related to '<query>' in this codebase." |
| E-MEM | `memory.md` missing | T2 Warn, proceed with code-only analysis |
