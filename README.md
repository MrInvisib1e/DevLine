# DevFlow

A skill library that makes AI behave like a senior engineer — not an order-taker.

DevFlow is stack-agnostic and built around four principles:

1. **PRD first** — challenge and document intent before any planning or code
2. **Domain before implementation** — interrogate technical constraints informed by the PRD
3. **Vertical slices** — every feature increment is a complete, tested, independently reviewed capability
4. **Accurate context** — AI maintains a machine-readable codebase knowledge graph per developer, per branch, self-correcting as code evolves

---

## What's inside

| Skill | Trigger | What it does |
|-------|---------|--------------|
| `/init` | Once per repo | Scan codebase, classify files, build SQLite knowledge graph |
| `/feature` | Start a feature | PRD → domain analysis → vertical slices → integration test → final review |
| `/feature quick` | Small change | Skip PRD phase, go straight to slices |
| `/fix` | Bug or failing test | Hypothesis-driven debugging scoped by memory context |
| `/review` | Before merge | Architecture-aware review against project conventions |
| `/plan` | Plan without coding | Memory-aware implementation plan, no execution |
| `/mem-sync` | Stale memory | Verify and refresh memory before any skill that reads it |
| `/verify` | Before claiming done | Run tests/build/lint and confirm all pass |

Eight shell scripts handle mechanical operations. Skills reason on top of their output — the AI never manually parses git.

```
bin/
  df-init        # scan repo, build initial memory + SQLite graph
  df-sync        # patch memory after every commit (--quick for hooks)
  df-explain     # query the knowledge graph (ranked, node, or diff)
  df-migrate     # migrate from JSON to SQLite graph store
  df-test        # run declared test for a named slice
  df-workspace   # manage workspace registry
  df-export      # dump memory as markdown or JSON
  df-resolve     # resolve graph conflicts between branches
```

---

## Prerequisites

- macOS or Linux (Windows via WSL2)
- `git` ≥ 2.20
- `jq` ≥ 1.6
- `sqlite3` ≥ 3.35

> **macOS note:** `sqlite3` ships with macOS. `flock` is not available by default — DevFlow falls back to PID-based lock files automatically.

---

## Installation

### Step 1 — Clone the repo

```bash
git clone https://github.com/<your-username>/Development-Flow.git ~/.devflow
```

Then add `~/.devflow/bin` to your PATH (skills need the shell scripts):

```bash
# Add to ~/.zshrc or ~/.bashrc
export PATH="$HOME/.devflow/bin:$PATH"
source ~/.zshrc  # or restart your terminal
```

### Step 2 — Connect to your AI platform

---

#### Claude Code

Claude Code loads skills referenced in `CLAUDE.md`. Copy the provided template to your user-level config:

```bash
cat ~/.devflow/CLAUDE.md >> ~/.claude/CLAUDE.md
```

This tells Claude Code where to find the DevFlow skills. No plugin marketplace needed — skills are loaded on demand when you use `/init`, `/feature`, `/fix`, etc.

**Optional — auto-inject bootstrap at session start:**

If you want DevFlow to announce itself automatically at the start of every Claude Code session (like Superpowers does), you need a GitHub-hosted marketplace repo. Once you've set one up:

```bash
/plugin marketplace add <your-github-username>/devflow-marketplace
/plugin install devflow@devflow-marketplace
```

The marketplace approach runs `hooks/session-start` which injects `skills/using-devflow/SKILL.md` into every session context automatically. Without it, skills still work — they're just loaded on first use rather than pre-announced.

**Verify:**
```bash
df-explain --rank   # should print ranked nodes (run inside a git repo after /init)
```

---

#### OpenCode

Add to your `opencode.json`:
```json
{
  "plugin": ["devflow@git+https://github.com/<your-username>/Development-Flow.git"]
}
```

OpenCode installs the plugin directly from git and adds `bin/` to PATH automatically. No extra setup.

---

#### Gemini CLI

```bash
gemini extensions install https://github.com/<your-username>/Development-Flow
```

---

#### Cursor

In Cursor Agent chat, register the marketplace first, then install (requires a published marketplace repo — see Claude Code note above).

Manual fallback: add the skills path to your Cursor CLAUDE.md equivalent.

---

#### Codex

See [`.codex/INSTALL.md`](.codex/INSTALL.md) for manual setup.

---

## Quick Start

1. Install DevFlow using your platform's method above
2. In any git repository: start a conversation and type `/init`
3. DevFlow scans your codebase, detects the stack, classifies all files — shows you a summary and asks for one confirmation before writing
4. A post-commit hook is installed — memory stays current automatically from here
5. Use `/feature`, `/fix`, `/review`, etc. as needed

---

## Usage

### Initialize a repo

```
/init
```

DevFlow automatically detects your stack, workspace name, and classifies all files (test, config, docs, infra, data, deps, script, source). You see one summary gate before anything is written.

After init:
- `.devflow/graph.db` — SQLite knowledge graph (gitignored, local per developer)
- `.devflow/active/memory.md` — top nodes ranked by PageRank, architecture overview
- Git hooks installed — `df-sync --quick` runs on every commit, keeping the graph current

**Re-init** (update mode — patches forward, never wipes existing intent):
```
/init
```

**Full reset:**
```bash
df-init --reset
```

---

### Build a feature

```
/feature "Add comment reactions"
```

DevFlow walks through six phases:

| Phase | Gates | What happens |
|-------|-------|-------------|
| 0 — PRD | **T3: approval** | Documents your intent and acceptance criteria |
| 1 — Domain | none | Runs `df-explain --rank`, reads `memory.md`, maps blast radius |
| 2 — Slices | **T3: approval** | Decomposes into vertical slices (each = complete, testable capability) |
| 3 — Execution | none | Implements slices, runs tests, retries up to 3× on failure |
| 4 — Integration | none | Tests assembled slices together using contract manifest |
| 5 — Review | none | Architecture-aware final review |
| 6 — Completion | **T3: merge/PR/keep** | Verifies tests pass, syncs memory, archives plan |

**Quick mode** (no PRD, 1–3 slices):
```
/feature quick "Fix missing avatar fallback"
```

**Resume an interrupted feature:**
```
/feature resume
```

---

### Fix a bug

```
/fix "comments endpoint returns 500 on empty body"
```

DevFlow:
1. **T2:** Infers the relevant node and prints it — proceeds immediately, no confirmation needed
2. Runs `df-explain` on that node to understand context
3. Forms a hypothesis before touching any code
4. Applies the fix and runs tests
5. Retries with a revised hypothesis on failure (max 3 cycles)
6. **T3:** Surfaces findings to you only if all 3 cycles fail

The fix is not done until the test passes.

---

### Review before merge

```
/review
```

DevFlow reads `memory.md` (architecture + conventions) before looking at any diff, then flags violations:

| Severity | Example findings |
|----------|-----------------|
| **BLOCKING** | Direct HTTP call where async messaging is the convention |
| **WARNING** | Naming deviation; missing test for new functionality |
| **NOTE** | Unclassified files; inbound nodes not in diff but affected |

Every finding cites the specific convention from `memory.md` that was violated. No subjective judgments.

---

### Query the knowledge graph

```bash
# Ranked view — most important nodes first (PageRank)
df-explain --rank

# Ranked view with token budget (useful for scripting)
df-explain --rank --budget 512

# Specific node or file
df-explain CommentService
df-explain src/routes/CommentController.svelte

# What changed in the graph between commits
df-explain --diff HEAD~5 HEAD
```

---

### Inspect and manage memory

```bash
# Show current memory summary
cat .devflow/active/memory.md

# Export full memory as markdown
df-export

# Export as JSON
df-export --format json

# Snapshot current memory
df-export --snapshot

# Restore a snapshot
df-export --restore 2026-05-01T14-30-00Z
```

---

## How memory works

Memory is **gitignored and local per developer**. No shared memory, no merge conflicts, no cross-developer pollution. Each developer builds their own via `/init` and keeps it current via `df-sync`.

```
.devflow/
  graph.db              # SQLite knowledge graph (primary store)
  config.json           # schema version, last_synced SHA, stack info
  cache/
    content-hashes.json # SHA256 per file — skips unchanged files on sync
  branches/
    main/
      memory.json       # graph metadata (source of truth for config)
      memory.md         # tiered render: Stack + Top 50 nodes + Edge summary
      nodes.json        # human-readable node export (generated on demand)
      edges.json        # human-readable edge export (generated on demand)
    feature-comments/
      memory.json
      memory.md
  active -> branches/main/  # symlink: current branch's memory
```

When you switch branches, the `active` symlink is updated automatically.

**memory.md is capped at ~2,500 tokens.** It shows the top ~50 nodes ranked by PageRank (most-connected nodes first) plus an edge summary. Use `df-explain --rank` for the full ranked graph or `df-explain <node>` to drill into any specific node.

---

## Autonomy model

DevFlow uses three tiers — you're only interrupted when it matters:

| Tier | Behaviour | Examples |
|------|-----------|---------|
| **T1 Silent** | Does it, no output | Stack detection, file classification, cache checks |
| **T2 Inform** | Does it, prints one-line summary | Node inference, memory sync results, hypothesis file list |
| **T3 Gate** | Presents options, waits for you | PRD approval, slice plan, feature completion strategy |

Net result: `/feature` has 3 gates. `/fix` has 1 (exhausted cycles). `/review` has 0. `/init` has 1 (final summary before write).

---

## Project layout

```
Development-Flow/
  bin/                        # 8 shell scripts
    lib/ts-extract            # tree-sitter AST extraction helper
  skills/
    using-devflow/SKILL.md    # bootstrap skill (loaded at session start)
    _shared.md                # shared tier definitions, SIF format rules
    init/SKILL.md
    feature/
      SKILL.md
      phases/                 # 7 phase files + resume.md
      agents/
        prompts/              # structured prompt templates
        output-validation.md  # 8-check output validation pipeline
    fix/SKILL.md
    mem-sync/SKILL.md
    review/SKILL.md
    plan/SKILL.md
    verify/SKILL.md
  hooks/                      # Claude Code + Cursor session-start hooks
  .opencode/plugins/          # OpenCode plugin
  .claude-plugin/             # Claude Code plugin manifest
  .cursor-plugin/             # Cursor plugin manifest
  gemini-extension.json       # Gemini CLI extension
  .codex/INSTALL.md           # Codex manual install guide
  tests/                      # bats test suite (51 tests)
  docs/
    specs/                    # design specs
    plans/                    # implementation plans
```

---

## Running DevFlow's own tests

```bash
# All shell script tests (requires bats-core)
bats tests/

# Individual suites
bats tests/df-sync.bats
bats tests/df-init.bats
bats tests/df-explain.bats
```

Tests use fixture repos and mock AI calls via `DEVFLOW_AI_MOCK=1` — no real API calls in CI.

---

## What DevFlow is not

- **Not a code generator** — it reasons about architecture and asks expert questions
- **Not a replacement for tests** — it enforces test coverage per slice, not a test writer
- **Not a shared team tool** — memory is local per developer by design
- **Not opinionated about stack** — it learns your stack from the codebase on init
