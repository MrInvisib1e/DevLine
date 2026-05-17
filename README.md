# Devline

A skill library that makes AI behave like a senior engineer — not an order-taker.

Devline is stack-agnostic and built around four principles:

1. **PRD first** — challenge and document intent before any planning or code
2. **Domain before implementation** — interrogate technical constraints informed by the PRD
3. **Vertical slices** — every feature increment is a complete, tested, independently reviewed capability
4. **Accurate context** — AI uses a semantic + structural codebase knowledge graph, kept current automatically

---

## What's inside

| Command | Trigger | What it does |
|---------|---------|--------------|
| `/dl-init` | Once per repo | Index codebase via codebase-memory-mcp, write `memory.md` |
| `/dl-feature` | Start a feature | PRD → domain analysis → vertical slices → two-stage review → completion |
| `/dl-feature quick` | Small change | Fewer questions, 1–3 slices, same review rigor |
| `/dl-fix` | Bug or failing test | 4-phase root-cause investigation + TDD fix cycle |
| `/dl-review` | Before merge | Convention-driven review: naming, coverage, dead code, clones, impact radius |
| `/dl-plan` | Plan without coding | Brainstorm → research tiers → memory-aware implementation plan |
| `/dl-sync` | Stale memory | Regenerate `memory.md` from codebase-memory-mcp |
| `/dl-verify` | Before claiming done | Run tests/build/typecheck and confirm all pass |
| `/dl-benchmark` | Test a skill | A/B test any skill against falsifiable assertions |
| `/web-style` | UI/web features | 6-dimension styling + accessibility audit (WCAG 2.1 AA) |

Shell scripts handle mechanical operations. Skills reason on top of their output.

```
bin/
  dl-init        # initialize Devline + index via codebase-memory-mcp
  dl-explain     # query the knowledge graph (rank, impact, dead code, clones)
  dl-check       # run quality hooks (lint/format/typecheck)
  dl-log         # append structured session events to .devline/sessions/session.jsonl
  dl-test        # run declared test for a named slice
  dl-workspace   # manage workspace registry
  dl-install     # install Devline across platforms
  dl-benchmark   # A/B test skills
  devline        # dispatcher CLI
```

---

## Prerequisites

- macOS or Linux (Windows via WSL2)
- `git` ≥ 2.20
- `jq` ≥ 1.6
- `node` ≥ 18 (for codebase-memory-mcp)

> **codebase-memory-mcp** is the knowledge graph engine. Run `dl-install --mcp` to install and configure it.

---

## Installation

### One command

```bash
git clone https://github.com/MrInvisib1e/devline.git ~/.devline
~/.devline/bin/dl-install
~/.devline/bin/dl-install --mcp
```

`dl-install` handles everything automatically:
- Adds `~/.devline/bin` to your PATH (in `~/.zshrc` / `~/.bashrc`)
- Registers Devline as a plugin in Claude Code, OpenCode, Gemini CLI, Cursor
- Updates `~/.claude/CLAUDE.md` with skill paths
- Idempotent — safe to re-run after updates

`dl-install --mcp` installs and configures `codebase-memory-mcp`:
- Installs via npm globally
- Registers the MCP server in your agent's config (Claude Code, OpenCode)

**After install:** restart your terminal, then in any git repo type `/dl-init`.

**Flags:**
```bash
dl-install --dry-run                    # preview changes, write nothing
dl-install --platform claude            # Claude Code only
dl-install --platform opencode          # OpenCode only
dl-install --mcp                        # install + configure codebase-memory-mcp only
dl-install --install-dir /path/to/repo  # if installed somewhere other than ~/.devline
```

---

### Platform details

#### Claude Code

`dl-install` creates a local plugin registration that:
- Runs `hooks/session-start` at the beginning of every session
- Injects `skills/using-devline/SKILL.md` into context (announces Devline + skill table)
- Skills are loaded on demand — type `/dl-init`, `/dl-feature`, `/dl-fix`, etc.

**Verify:**
```bash
dl-explain --rank   # should print ranked nodes (run inside a git repo after /dl-init)
```

---

#### OpenCode

`dl-install` adds the local path to `opencode.json` automatically. Or manually:
```json
{
  "plugin": ["devline@git+https://github.com/MrInvisib1e/devline.git"]
}
```

---

#### Gemini CLI

```bash
gemini extensions install https://github.com/MrInvisib1e/devline
```

---

#### Cursor

Manual fallback: add the skills path to your Cursor settings. See `.cursor-plugin/plugin.json`.

---

#### Codex

See [`.codex/INSTALL.md`](.codex/INSTALL.md) for manual setup.

---

## Quick Start

1. Install Devline using your platform's method above
2. Run `dl-install --mcp` to install codebase-memory-mcp
3. In any git repository: start a conversation and type `/dl-init`
4. Devline indexes your codebase via codebase-memory-mcp, writes `memory.md`
5. A post-commit hook and post-checkout hook keep memory current automatically
6. Use `/dl-feature`, `/dl-fix`, `/dl-review`, etc. as needed

---

## Usage

### Initialize a repo

```
/dl-init
```

Devline automatically:
- Indexes your codebase via codebase-memory-mcp (155 languages, tree-sitter)
- Detects your stack (Node.js, .NET, Python, Go, Rust, Ruby)
- Writes `.devline/config.json` with stack info and quality hooks
- Renders `.devline/memory.md` — architecture overview + top nodes (~2,500 tokens)
- Installs a post-commit hook (memory update after each commit)
- Installs a post-checkout hook (memory update after each branch switch)

**Re-init** (re-index after major structural changes):
```
/dl-init
```

**Full reset:**
```bash
dl-init --reset
```

**Multi-project (monorepo):**
```bash
dl-init                    # run in each subproject directory
dl-init --orchestrator     # run at root to bind all subprojects
```

---

### Build a feature

```
/dl-feature "Add comment reactions"
```

Devline walks through six phases:

| Phase | Gates | What happens |
|-------|-------|-------------|
| 0 — PRD | **T3: approval** | Documents your intent and acceptance criteria. Detects greenfield projects automatically and asks stack/architecture questions. |
| 1 — Domain | none | Queries knowledge graph, maps blast radius |
| 2 — Slices | **T3: approval** | Decomposes into vertical slices (each = complete, testable capability) |
| 3 — Execution | none | Implements slices, runs tests, retries up to 3× on failure |
| 4 — Integration | none | Tests assembled slices together |
| 5 — Review | none | Two-stage review: spec compliance first, then code quality |
| 6 — Completion | **T3: merge/PR/keep/discard** | Verifies tests pass, syncs memory, archives plan, cleans up worktree |

**Quick mode** (fewer questions, 1–3 slices):
```
/dl-feature quick "Fix missing avatar fallback"
```

**Resume an interrupted feature:**
```
/dl-feature resume
```

---

### Fix a bug

```
/dl-fix "comments endpoint returns 500 on empty body"
```

Devline uses a 4-phase systematic investigation:

1. **Root Cause Investigation** — read error messages, reproduce, trace recent changes, gather evidence at each component boundary
2. **Pattern Analysis** — find working examples in codebase, compare against references, identify differences
3. **Hypothesis & Testing** — form a single hypothesis, test minimally, one variable at a time
4. **Implementation** — write failing test first (TDD), apply fix at root cause (not symptom)

If 3 cycles fail, Devline escalates: surfaces all hypotheses + evidence and asks for your direction. For complex scope, it bails to `/dl-feature` rather than silently expanding.

---

### Review before merge

```
/dl-review
```

Devline reads `memory.md` (architecture + conventions) before looking at any diff, then flags violations:

| Severity | Example findings |
|----------|-----------------|
| **BLOCKING** | Direct HTTP call where async messaging is the convention |
| **WARNING** | Naming deviation; missing test for new functionality |
| **NOTE** | Dead code; near-clone detected; impact radius not in diff |

Every finding cites the specific convention from `memory.md` that was violated. No subjective judgments.

Nine default checks: naming, test-coverage, unclassified, impact-radius, dead-code, clone-detection + any user-defined checks in `config.json`.

---

### Style and accessibility audit

```
/web-style src/components/CommentCard.svelte
```

Evaluates web components across 6 dimensions:

| Dimension | What it checks |
|-----------|----------------|
| Design Tokens | No hardcoded hex/rgb; spacing from scale; typography from type scale |
| Accessibility | WCAG 2.1 AA contrast ratios; ARIA patterns; focus management; keyboard nav |
| Responsive Design | Mobile-first at 320px; touch targets ≥44px; no horizontal scroll |
| Design System | Spacing rhythm; dark mode; status = color+icon+text |
| Polish | 12-dimension quality check (alignment, states, micro-interactions, etc.) |
| Anti-Patterns | CSS/HTML/animation smells |

Auto-triggered when `/dl-feature` detects a web stack.

---

### Query the knowledge graph

```bash
# Top nodes by connectivity
dl-explain --rank

# With token budget
dl-explain --rank --budget 512

# Specific symbol or concept
dl-explain CommentService
dl-explain "authentication flow"

# Blast radius of uncommitted changes
dl-explain --impact

# Dead code (zero-caller functions)
dl-explain --dead-code

# Near-clone pairs
dl-explain --clones

# Scope to one project (orchestrator mode)
dl-explain --project backend --rank
```

---

### Quality hooks

```bash
# Run lint + format + typecheck for current project
dl-check

# Typecheck only (blocking)
dl-check --typecheck-only

# Lint only (advisory)
dl-check --lint-only

# Non-interactive CI mode
dl-check --headless
```

Exit codes: `0` = all pass, `1` = typecheck failed (blocking), `2` = lint/format issues (advisory).

Configure in `.devline/config.json`:
```json
"quality_hooks": {
  "lint": "npx eslint .",
  "format": "npx prettier --write .",
  "typecheck": "npx tsc --noEmit"
}
```

---

### Session log

```bash
# Log an event from a skill step
dl-log --skill dl-fix --phase root-cause --step hypothesis --tokens 1200

# View current session
cat .devline/sessions/session.jsonl | jq .
```

`dl-log` appends structured JSONL events to `.devline/sessions/session.jsonl`. Skills use it to record phase transitions, token estimates, and elapsed time. Useful for auditing what happened in a long session.

---

### Memory

Memory is a single `.devline/memory.md` — gitignored and local per developer. Updated automatically by the post-commit hook after every commit and the post-checkout hook after every branch switch.

```
.devline/
  config.json           # stack info, review checks, auto_skills, quality_hooks
  memory.md             # architecture overview + top nodes (~2,500 tokens)
  plans/                # implementation plans (one dir per feature)
  sessions/             # session event logs (session.jsonl per session)
    session.jsonl
```

**memory.md is capped at ~2,500 tokens.** Use `dl-explain --rank` for the full ranked graph or `dl-explain <symbol>` to drill into any node.

---

## Autonomy model

Devline uses three tiers — you're only interrupted when it matters:

| Tier | Behaviour | Examples |
|------|-----------|---------|
| **T1 Silent** | Does it, no output | Stack detection, cache checks, memory sync |
| **T2 Inform** | Does it, prints one-line summary | Node inference, branch switch sync, token warnings |
| **T3 Gate** | Presents options, waits for you | PRD approval, slice plan, feature completion |

Net result: `/dl-feature` has 3 gates. `/dl-fix` has 1 (exhausted cycles). `/dl-review` has 0. `/dl-init` has 1 (final summary before write).

---

## Project layout

```
devline/
  bin/
    dl-init, dl-explain, dl-check, dl-log, dl-test
    dl-workspace, dl-install, dl-benchmark
    devline
  skills/
    using-devline/SKILL.md    # bootstrap (loaded at session start)
    _shared.md                # tier definitions, token budget, session log, memory sync, SIF rules
    dl-init/SKILL.md
    dl-feature/
      SKILL.md
      phases/                 # 7 phase files + resume.md
      agents/
        final-review.md
        spec-reviewer.md      # PRD compliance reviewer (stage 1 of two-stage review)
        output-validation.md
    dl-fix/SKILL.md
    dl-review/SKILL.md
    dl-plan/SKILL.md
    dl-sync/SKILL.md
    dl-verify/SKILL.md
    dl-benchmark/SKILL.md
    web-style/                # styling + accessibility audit (v0.6.0)
      SKILL.md
      accessibility-wcag-aa.md
      design-system.md
      responsive-design.md
      anti-patterns.md
    tdd/SKILL.md              # RED-GREEN-REFACTOR discipline
    receiving-review/SKILL.md # technical rigor on review feedback
    worktrees/SKILL.md        # git worktree isolation
    writing-skills/SKILL.md   # skill authoring with TDD
  hooks/
    post-commit               # async memory regen after each commit
    post-checkout             # async memory regen after branch switch
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

## Running Devline's own tests

```bash
# All shell script tests (requires bats-core)
bats tests/

# Individual suites
bats tests/dl-init.bats
bats tests/dl-explain.bats
```

Tests use fixture repos. No real API calls.

---

## What Devline is not

- **Not a code generator** — it reasons about architecture and asks expert questions
- **Not a replacement for tests** — it enforces test coverage per slice, not a test writer
- **Not a shared team tool** — memory is local per developer by design
- **Not opinionated about stack** — it learns your stack from the codebase on init
