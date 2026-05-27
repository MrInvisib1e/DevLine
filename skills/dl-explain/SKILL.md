---
name: devline-explain
description: Business logic explanation — explains a feature, file, or application using memory and code context
requires: [dl-sync]
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

1. Check `.devline/` exists — if not: HALT — "Run `/dl-init` first."
2. Check memory staleness:
   ```bash
   LAST=$(python3 -c "import json; print(json.load(open('.devline/config.json')).get('last_synced',''))")
   HEAD=$(git rev-parse HEAD)
   ```
   If `LAST != HEAD`: run `/dl-sync`. T2 Inform: "[Devline] Memory was stale — synced."

---

## Entry Routing

| Invocation | Query type | Notes |
|-----------|-----------|-------|
| `/dl-explain <query>` | Feature or concept search | Search memory + graph |
| `/dl-explain --file <path>` | File/module explanation | Read file directly |
| `/dl-explain` (no args) | App-level overview | Use memory.md architecture section |
| Query < 3 chars | App-level overview | T2 Inform: "Query too short — showing app overview." |
| Query = "everything" / "all" / "app" | App-level overview | Scope automatically |
| DEFAULT | Feature search | Proceed to Step 1 |

---

## Step 1: Scope Detection (T2 Inform)

Classify the query into one of three scopes:

| Scope | Criteria | What to read |
|-------|---------|-------------|
| `app` | No args, or query matches whole-app keywords | `memory.md` architecture + top-level README |
| `file` | `--file` flag, or query matches a file path pattern (`*.ts`, `/src/...`) | The specified file directly |
| `feature` | Named concept, domain term, or feature name | Graph + memory + relevant source files |
| DEFAULT | `feature` | Proceed as feature scope |

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

For `feature` or `file` scope, run:

```bash
dl-explain <query>
# or for file scope:
dl-explain --node <path>
```

| Result | Action |
|--------|--------|
| Symbols found | Note relevant file paths and call relationships |
| No results | T2 Warn: "[Devline] Graph query returned no results — falling back to file search." Run `grep -r <query> . --include="*.ts" --include="*.js" --include="*.py" -l` |
| dl-explain not found | T2 Warn: "[Devline] dl-explain binary missing — falling back to file search." |
| Exit non-zero | T2 Warn: "[Devline] Graph query failed — falling back to file search." |
| DEFAULT | Continue with whatever was found |

### 2c. Read source files

<scope>
READ: up to 5 files identified by the graph or file search. DO NOT read entire directories.
</scope>

For each relevant file found (max 5), read it completely. These are the basis of the explanation.

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

## Error Reference

| Code | Trigger | Action |
|------|---------|--------|
| E01 | `.devline/` missing | HALT — "Run `/dl-init` first." |
| E13 | `dl-explain` binary fails | T2 Warn, fall back to grep-based file search |
| E-NF | No files found for query | Print exactly: "Couldn't find anything related to '<query>' in this codebase." |
| E-MEM | `memory.md` missing | T2 Warn, proceed with code-only analysis |
