# DevFlow

A Claude Code skill library that makes AI behave like a senior engineer — not an order-taker.

DevFlow is stack-agnostic and built around four principles:

1. **PRD first** — challenge and document intent before any planning or code
2. **Domain before implementation** — interrogate technical constraints and edge cases informed by the PRD
3. **Vertical slices** — every feature increment is a complete, tested, independently reviewed capability
4. **Accurate context** — AI maintains a machine-readable codebase model per developer, per branch, self-correcting as code evolves

---

## What's inside

| Skill | Trigger | What it does |
|-------|---------|--------------|
| `/init` | Once per repo | Scan codebase, classify files, build graph memory |
| `/feature` | Start a feature | PRD interrogation → domain analysis → vertical slice execution → integration test → final review |
| `/fix` | Bug or failing test | Hypothesis-driven debugging scoped by memory context |
| `/review` | Before merge | Architecture-aware review against project conventions |
| `/mem-sync` | Stale memory | Verify and refresh memory before any skill that reads it |

Seven shell scripts handle mechanical operations. Skills reason on top of their output — the AI never manually parses git.

```
bin/
  df-init        # scan repo, build initial memory
  df-sync        # patch memory after every commit
  df-test        # run declared test for a named slice
  df-workspace   # manage workspace registry
  df-explain     # print memory context for any file or symbol
  df-export      # dump memory as markdown
  df-resolve     # resolve graph conflicts between branches
```

---

## Prerequisites

- macOS or Linux (Windows via WSL2)
- `git` ≥ 2.20
- `jq` ≥ 1.6
- Claude Code ([install guide](https://docs.anthropic.com/en/docs/claude-code))

> **macOS note:** `flock` is not available by default on macOS. DevFlow falls back to PID-based lock files automatically — no action needed.

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/<you>/devflow ~/.devflow
```

### 2. Make scripts executable

```bash
chmod +x ~/.devflow/bin/df-*
```

### 3. Add scripts to PATH

**zsh (default on macOS):**
```bash
echo 'export PATH="$HOME/.devflow/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**bash:**
```bash
echo 'export PATH="$HOME/.devflow/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 4. Register skills with Claude Code

Open (or create) `~/.claude/CLAUDE.md` and add the following block:

```markdown
## DevFlow Skills

The following skills are available:

- **init** (`~/.devflow/skills/init/SKILL.md`): Initialize a repo with DevFlow memory
- **feature** (`~/.devflow/skills/feature/SKILL.md`): PRD → domain → slice → implement → review
- **mem-sync** (`~/.devflow/skills/mem-sync/SKILL.md`): Keep memory in sync with code changes
- **fix** (`~/.devflow/skills/fix/SKILL.md`): Fix a bug using memory-aware context
- **review** (`~/.devflow/skills/review/SKILL.md`): Review code against project conventions
```

Claude Code reads `~/.claude/CLAUDE.md` at session start. No restart or plugin registration required — changes take effect on the next session.

### 5. Verify installation

Run the following checklist in your terminal:

```bash
# All 7 scripts are on PATH
which df-init df-sync df-test df-workspace df-explain df-export df-resolve

# Scripts are executable
ls -la ~/.devflow/bin/df-*

# Version check
df-init --version
```

Then open Claude Code in any directory and type `/init`. You should see the DevFlow init skill activate and begin asking about your repo.

---

## Usage

### Initialize a repo

Run once inside any git repo:

```
/init
```

DevFlow scans your codebase, infers the stack, classifies files into a graph of nodes and edges, and writes `.devflow/` (gitignored). You'll be asked to confirm the detected stack, name the workspace, and review any files that couldn't be auto-classified.

After init, a post-commit hook is installed. From this point on, `df-sync` runs automatically after every commit and keeps memory current.

---

### Build a feature

```
/feature "Add comment reactions"
```

DevFlow walks through six phases:

| Phase | What happens |
|-------|-------------|
| 0 — PRD | Asks 6 targeted questions to challenge and document your intent. Each answer requires a testable acceptance criterion before moving on. |
| 1 — Domain analysis | Runs `df-explain` on affected modules, reads `memory.md`, maps the blast radius of the change. |
| 2 — Slice planning | Decomposes the feature into vertical slices (each slice = one complete, testable user-facing capability). |
| 3 — Slice execution | Implements slices, runs tests, performs slice-level review. Retries up to 3 times on failure. |
| 4 — Integration test | Tests the assembled slices together. |
| 5 — Final review | Architecture-aware review of the complete change. |
| 6 — Completion | Syncs memory, archives the plan, hands off to git. |

**Quick mode** (fewer questions, 1–3 slices):
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
1. Infers the relevant node from your description and asks you to confirm
2. Runs `df-explain` to understand what depends on it and what it depends on
3. Forms a hypothesis before touching any code
4. Applies the fix and runs tests
5. Retries with a revised hypothesis if tests fail (max 3 cycles)

The fix is not done until the test passes.

---

### Review before merge

```
/review
```

Or against a specific base:

```
/review --base main
```

DevFlow reads `memory.md` (architecture + conventions) before looking at any diff, then runs `df-explain` on every changed file and flags violations:

| Severity | Example findings |
|----------|-----------------|
| **BLOCKING** | Direct HTTP call where async messaging is the convention; DI lifetime mismatch |
| **WARNING** | Naming deviation; missing test coverage for new functionality; contract change without memory update |
| **NOTE** | Unclassified files; inbound nodes that may be affected but aren't in the diff |

Every finding cites the specific convention from `memory.md` that was violated — no subjective judgments.

**Verdict:** `PASS` (no blocking, ≤2 warnings) / `CONCERNS` (no blocking, 3+ warnings) / `BLOCKING` (any blocking finding)

---

### Inspect any file or symbol

```bash
df-explain CommentService
df-explain src/routes/CommentController.svelte
df-explain --depth 2 entity:Comment
```

Prints the node's intent, type, file path, what it depends on, and what depends on it. Useful for understanding the impact radius of a change before writing code.

---

### Resolve graph conflicts

When branches are merged, DevFlow may detect conflicting `intent` values for the same node:

```bash
df-resolve --list                                    # see all conflicts
df-resolve --accept a entity:Comment                 # accept branch A's intent
df-resolve --rewrite-intent entity:Comment "..."     # write your own intent
df-resolve --rewrite-intent entity:Comment --auto    # revert to AI-managed
```

---

### Export memory

```bash
df-export                   # dump memory.md to stdout
df-export --format json     # dump raw memory.json
df-export --snapshot        # snapshot current memory to .devflow/snapshots/
```

Snapshots can be restored:

```bash
df-export --restore 2026-05-01T14-30-00Z
```

---

## How memory works

Memory is **gitignored and local per developer**. No shared memory, no merge conflicts, no cross-developer pollution. Each developer builds their own via `/init` and keeps it current via `df-sync` (runs automatically post-commit).

Each branch gets an isolated memory snapshot:

```
.devflow/
  config.json           # schema version, last_synced SHA, dirty flag
  branches/
    main/
      memory.json       # source of truth — owned by df-sync
      memory.md         # auto-generated render — read by skills
      nodes.json        # graph nodes (one per logical unit)
      edges.json        # dependency edges between nodes
    feature-comments/
      memory.json
      memory.md
      nodes.json
      edges.json
```

When you switch branches, DevFlow switches memory context automatically.

---

## Re-initialization

If `.devflow/` already exists, `/init` runs in update mode — it patches memory forward without wiping existing intent strings or resetting the graph.

**When to re-init:**
- After a major stack change (new framework, language version bump)
- After cloning a repo where `.devflow/` was deleted (e.g. `git clean -fdx`)

**Full reset** (wipes and rebuilds from scratch):
```
df-init --reset
```

---

## Undo operations

### Undo a bad classifier
```bash
df-sync --undo-classifier "*.reaction.ts"
```

### Fix a wrong intent
```bash
df-explain Comment                                      # see current
df-resolve --rewrite-intent entity:Comment "New intent"
df-resolve --rewrite-intent entity:Comment --auto       # revert to AI
```

---

## Project layout

```
~/.devflow/
  bin/                 # 7 shell scripts (add to PATH)
  skills/
    init/SKILL.md
    feature/SKILL.md
    feature/agents/    # agent templates for sub-tasks
    fix/SKILL.md
    mem-sync/SKILL.md
    review/SKILL.md
  tests/               # bats test suite for shell scripts
  docs/                # design specs and architecture docs
```

---

## Running DevFlow's own tests

```bash
# All shell script tests (requires bats-core)
bats tests/

# One script's tests
bats tests/df-sync.bats

# Lint scripts
shellcheck bin/df-*
```

Tests use fixture repos and mock AI calls via `DEVFLOW_AI_MOCK=1` — no real API calls in CI.

---

## What DevFlow is not

- **Not a code generator** — it reasons about architecture and asks expert questions
- **Not a replacement for tests** — it enforces test coverage per slice, it does not write tests for you
- **Not a shared team tool** — memory is local per developer by design
- **Not opinionated about stack** — it learns your stack from the codebase on init
