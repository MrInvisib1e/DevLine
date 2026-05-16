# DevFlow

A skill library that makes AI behave like a senior engineer — not an order-taker.

DevFlow is stack-agnostic and built around four principles:

1. **PRD first** — challenge and document intent before any planning or code
2. **Domain before implementation** — interrogate technical constraints informed by the PRD
3. **Vertical slices** — every feature increment is a complete, tested, independently reviewed capability
4. **Accurate context** — AI uses a semantic + structural codebase knowledge graph, kept current automatically

---

## What's inside

| Command | Trigger | What it does |
|---------|---------|--------------|
| `/df-init` | Once per repo | Index codebase via codebase-memory-mcp, write `memory.md` |
| `/df-feature` | Start a feature | PRD → domain analysis → vertical slices → integration test → final review |
| `/df-feature quick` | Small change | Skip PRD phase, go straight to slices |
| `/df-fix` | Bug or failing test | Behavior contract + hypothesis-driven debugging scoped by knowledge graph |
| `/df-review` | Before merge | Convention-driven review: naming, coverage, dead code, clones, impact radius |
| `/df-plan` | Plan without coding | Brainstorm → research tiers → memory-aware implementation plan |
| `/df-sync` | Stale memory | Regenerate `memory.md` from codebase-memory-mcp |
| `/df-verify` | Before claiming done | Run tests/build/typecheck and confirm all pass |
| `/df-benchmark` | Test a skill | A/B test any skill against falsifiable assertions |

Shell scripts handle mechanical operations. Skills reason on top of their output.

```
bin/
  df-init        # initialize DevFlow + index via codebase-memory-mcp
  df-explain     # query the knowledge graph (rank, impact, dead code, clones)
  df-check       # run quality hooks (lint/format/typecheck)
  df-test        # run declared test for a named slice
  df-workspace   # manage workspace registry
  df-install     # install DevFlow across platforms
  df-benchmark   # A/B test skills (stub in v4.0)
  devflow        # dispatcher CLI
  df             # alias for devflow
```

---

## Prerequisites

- macOS or Linux (Windows via WSL2)
- `git` ≥ 2.20
- `jq` ≥ 1.6
- `node` ≥ 18 (for codebase-memory-mcp)

> **codebase-memory-mcp** is the knowledge graph engine. Run `df-install --mcp` to install and configure it.

---

## Installation

### One command

```bash
git clone https://github.com/<your-username>/Development-Flow.git ~/.devflow
~/.devflow/bin/df-install
~/.devflow/bin/df-install --mcp
```

`df-install` handles everything automatically:
- Adds `~/.devflow/bin` to your PATH (in `~/.zshrc` / `~/.bashrc`)
- Registers DevFlow as a plugin in Claude Code, OpenCode, Gemini CLI, Cursor
- Updates `~/.claude/CLAUDE.md` with skill paths
- Idempotent — safe to re-run after updates

`df-install --mcp` installs and configures `codebase-memory-mcp`:
- Installs via npm globally
- Registers the MCP server in your agent's config (Claude Code, OpenCode)

**After install:** restart your terminal, then in any git repo type `/df-init`.

**Flags:**
```bash
df-install --dry-run                    # preview changes, write nothing
df-install --platform claude            # Claude Code only
df-install --platform opencode          # OpenCode only
df-install --mcp                        # install + configure codebase-memory-mcp only
df-install --install-dir /path/to/repo  # if installed somewhere other than ~/.devflow
```

---

### Platform details

#### Claude Code

`df-install` creates a local plugin registration that:
- Runs `hooks/session-start` at the beginning of every session
- Injects `skills/using-devflow/SKILL.md` into context (announces DevFlow + skill table)
- Skills are loaded on demand — type `/df-init`, `/df-feature`, `/df-fix`, etc.

**Verify:**
```bash
df-explain --rank   # should print ranked nodes (run inside a git repo after /df-init)
```

---

#### OpenCode

`df-install` adds the local path to `opencode.json` automatically. Or manually:
```json
{
  "plugin": ["devflow@git+https://github.com/<your-username>/Development-Flow.git"]
}
```

---

#### Gemini CLI

```bash
gemini extensions install https://github.com/<your-username>/Development-Flow
```

---

#### Cursor

Manual fallback: add the skills path to your Cursor settings. See `.cursor-plugin/plugin.json`.

---

#### Codex

See [`.codex/INSTALL.md`](.codex/INSTALL.md) for manual setup.

---

## Quick Start

1. Install DevFlow using your platform's method above
2. Run `df-install --mcp` to install codebase-memory-mcp
3. In any git repository: start a conversation and type `/df-init`
4. DevFlow indexes your codebase via codebase-memory-mcp, writes `memory.md`
5. A post-commit hook regenerates `memory.md` automatically after every commit
6. Use `/df-feature`, `/df-fix`, `/df-review`, etc. as needed

---

## Usage

### Initialize a repo

```
/df-init
```

DevFlow automatically:
- Indexes your codebase via codebase-memory-mcp (155 languages, tree-sitter)
- Detects your stack (Node.js, .NET, Python, Go, Rust, Ruby)
- Writes `.devflow/config.json` with stack info and quality hooks
- Renders `.devflow/memory.md` — architecture overview + top nodes (~2,500 tokens)
- Installs a post-commit hook to keep memory current

**Re-init** (re-index after major structural changes):
```
/df-init
```

**Full reset:**
```bash
df-init --reset
```

**Multi-project (monorepo):**
```bash
df-init                    # run in each subproject directory
df-init --orchestrator     # run at root to bind all subprojects
```

---

### Build a feature

```
/df-feature "Add comment reactions"
```

DevFlow walks through six phases:

| Phase | Gates | What happens |
|-------|-------|-------------|
| 0 — PRD | **T3: approval** | Documents your intent and acceptance criteria |
| 1 — Domain | none | Queries knowledge graph, maps blast radius |
| 2 — Slices | **T3: approval** | Decomposes into vertical slices (each = complete, testable capability) |
| 3 — Execution | none | Implements slices, runs tests, retries up to 3× on failure |
| 4 — Integration | none | Tests assembled slices together |
| 5 — Review | none | Convention-driven final review |
| 6 — Completion | **T3: merge/PR/keep/discard** | Verifies tests pass, syncs memory, archives plan |

**Quick mode** (no PRD, 1–3 slices):
```
/df-feature quick "Fix missing avatar fallback"
```

**Resume an interrupted feature:**
```
/df-feature resume
```

---

### Fix a bug

```
/df-fix "comments endpoint returns 500 on empty body"
```

DevFlow:
1. Documents a **behavior contract** (Given/When/Currently/Expected/Anti-regression)
2. **T2:** Infers the relevant node and prints it — proceeds immediately
3. Queries knowledge graph for that node's impact radius
4. Forms a hypothesis before touching any code
5. Applies the fix and runs tests
6. Retries with a revised hypothesis on failure (max 3 cycles)
7. **T3:** Surfaces findings to you only if all 3 cycles fail

The fix is not done until the test passes.

---

### Review before merge

```
/df-review
```

DevFlow reads `memory.md` (architecture + conventions) before looking at any diff, then flags violations:

| Severity | Example findings |
|----------|-----------------|
| **BLOCKING** | Direct HTTP call where async messaging is the convention |
| **WARNING** | Naming deviation; missing test for new functionality |
| **NOTE** | Dead code; near-clone detected; impact radius not in diff |

Every finding cites the specific convention from `memory.md` that was violated. No subjective judgments.

Nine default checks: naming, test-coverage, unclassified, impact-radius, dead-code, clone-detection + any user-defined checks in `config.json`.

---

### Query the knowledge graph

```bash
# Top nodes by connectivity
df-explain --rank

# With token budget
df-explain --rank --budget 512

# Specific symbol or concept
df-explain CommentService
df-explain "authentication flow"

# Blast radius of uncommitted changes
df-explain --impact

# Dead code (zero-caller functions)
df-explain --dead-code

# Near-clone pairs
df-explain --clones

# Scope to one project (orchestrator mode)
df-explain --project backend --rank
```

---

### Quality hooks

```bash
# Run lint + format + typecheck for current project
df-check

# Typecheck only (blocking)
df-check --typecheck-only

# Lint only (advisory)
df-check --lint-only

# Non-interactive CI mode
df-check --headless
```

Exit codes: `0` = all pass, `1` = typecheck failed (blocking), `2` = lint/format issues (advisory).

Configure in `.devflow/config.json`:
```json
"quality_hooks": {
  "lint": "npx eslint .",
  "format": "npx prettier --write .",
  "typecheck": "npx tsc --noEmit"
}
```

---

### Memory

Memory is a single `.devflow/memory.md` — gitignored and local per developer. Updated automatically by the post-commit hook.

```
.devflow/
  config.json     # stack info, review checks, auto_skills, quality_hooks
  memory.md       # architecture overview + top nodes (~2,500 tokens)
  plans/          # implementation plans (one dir per feature)
```

**memory.md is capped at ~2,500 tokens.** Use `df-explain --rank` for the full ranked graph or `df-explain <symbol>` to drill into any node.

---

## Autonomy model

DevFlow uses three tiers — you're only interrupted when it matters:

| Tier | Behaviour | Examples |
|------|-----------|---------|
| **T1 Silent** | Does it, no output | Stack detection, cache checks |
| **T2 Inform** | Does it, prints one-line summary | Node inference, memory sync results |
| **T3 Gate** | Presents options, waits for you | PRD approval, slice plan, feature completion |

Net result: `/df-feature` has 3 gates. `/df-fix` has 1 (exhausted cycles). `/df-review` has 0. `/df-init` has 1 (final summary before write).

---

## Project layout

```
Development-Flow/
  bin/
    df-init, df-explain, df-check, df-test
    df-workspace, df-install, df-benchmark
    devflow, df
  skills/
    using-devflow/SKILL.md    # bootstrap (loaded at session start)
    _shared.md                # tier definitions, config.json schema, SIF format rules
    df-init/SKILL.md
    df-feature/
      SKILL.md
      phases/                 # 7 phase files + resume.md
      agents/
        prompts/              # structured prompt templates
        output-validation.md
    df-fix/SKILL.md
    df-review/SKILL.md
    df-plan/SKILL.md
    df-sync/SKILL.md
    df-verify/SKILL.md
    df-benchmark/SKILL.md
    tdd/SKILL.md              # RED-GREEN-REFACTOR discipline
    receiving-review/SKILL.md # technical rigor on review feedback
    worktrees/SKILL.md        # git worktree isolation
    writing-skills/SKILL.md   # skill authoring with TDD
  hooks/
  .opencode/plugins/
  .claude-plugin/
  .cursor-plugin/
  gemini-extension.json
  .codex/INSTALL.md
  tests/
  docs/
    specs/
    plans/
```

---

## Running DevFlow's own tests

```bash
# All shell script tests (requires bats-core)
bats tests/

# Individual suites
bats tests/df-init.bats
bats tests/df-explain.bats
```

Tests use fixture repos. No real API calls.

---

## What DevFlow is not

- **Not a code generator** — it reasons about architecture and asks expert questions
- **Not a replacement for tests** — it enforces test coverage per slice, not a test writer
- **Not a shared team tool** — memory is local per developer by design
- **Not opinionated about stack** — it learns your stack from the codebase on init
