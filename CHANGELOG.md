# Changelog

All notable changes to Devline are documented here.

---

## [Unreleased]

### Memory & session hygiene

**Incremental `memory.md` updates**
- `bin/dl-init` now writes stable HTML-comment markers around each section (`architecture`, `top-nodes`, `recent-deltas`) and preserves any existing `recent-deltas` block on regeneration
- `skills/dl-feature/phases/phase-6-completion.md` Step 2 rewritten: appends a one-line delta entry (date · feature · files · new symbols) instead of regenerating the full memory file on every feature completion
- Falls back to full regen automatically when the delta block exceeds 20 entries (compaction) or when section markers are absent (recovery)
- Phase 6 sync messages now distinguish "incremental append (N pending)" vs "full regen (...)" so users see what actually happened

**Session log retention + index**
- `bin/dl-log` upgraded: new `feature` / `slice` correlation fields (read from `DEVLINE_FEATURE` / `DEVLINE_SLICE` env vars set by the orchestrator); per-event rotation when `session.jsonl` exceeds 1000 lines (renames to `session-YYYYMMDD-HHMMSS.jsonl`)
- New `bin/dl-log-index` script: rebuilds `.devline/sessions/index.json` mapping `feature-slug → {start_ts, end_ts, files:[{path, line_start, line_end, event_count}]}`
- Called from `/dl-sync` Step 2.7 and Phase 6 Artifact Cleanup, so the index is always current after any sync or feature completion
- `skills/_shared.md` Session Event Log section documents the new fields, retention behavior, and `index.json` schema
- Two new event types: `agent_timeout` (from M3 watchdog), `config_migrated` (from Mm4 migration)

### Config-driven fan-out

**`review_checks` upgraded to structured objects**
- `bin/dl-init` template seed and the in-repo `.devline/config.json` now write `review_checks` as `[{name, severity, convention, evidence_hint}]` instead of bare strings
- Schema documented in `skills/_shared.md` field reference
- New canonical migration helper in `_shared.md` → "Config Migration" auto-upgrades pre-0.7 configs the first time `/dl-sync` runs; idempotent; emits `config_migrated` event
- Unblocks the per-check parallel Tasks promised by `/dl-review` Phase 2 — each Task now gets a real `convention` string instead of a one-word prompt

**`/dl-plan` deep-tier research — real parallel Tasks**
- `skills/dl-plan/SKILL.md` Phase 2 deep tier rewritten with explicit Task dispatch contract mirroring `/dl-review` Phase 2
- New `skills/dl-plan/agents/` role files: `research-codebase.md`, `research-docs.md`, `research-coupling.md`
- New Phase 2.5 synthesis step: merges evidence, surfaces unresolved `open_questions` as a `dl:choice` before plan generation
- Replaces prose bullets that the orchestrator was previously executing serially

### Multi-agent reliability (phase-3 execution hardening)

**Per-agent watchdog**
- New section in `skills/dl-feature/phases/phase-3-execution.md` between "Output Validation Pipeline" and "Execution Loop Termination"
- 10-minute default deadline per agent dispatch (configurable via `config.json.agent_timeout_ms`)
- One re-dispatch with "previous attempt timed out" injected into Prior Work; second timeout marks slice stuck with `blocked_reason: "agent_timeout x2"`
- New slice JSON fields: `agent_dispatched_at`, `agent_completed_at`, `agent_elapsed_ms` per role
- New `dl-log` event: `agent_timeout`

**Partial-batch failure policy**
- "Merge Parallel Slices" section rewritten: now records `BATCH_BASELINE_SHA`, runs a pre-merge probe per slice, presents a `dl:choice` on mixed-conflict outcomes, and `git reset --hard`s the entire batch to baseline on unexpected mid-merge failure
- New slice JSON fields: `merge_probe ∈ {clean, conflict}`, `merge_result ∈ {merged, serialized_after_conflict, batch_aborted, manual_pending, rolled_back}`
- Closes the silent half-merged state when one slice of a parallel batch conflicted while others had already merged

**Test-skip criteria — single decision table**
- Replaces conflicting "Skip if ALL" / "Always dispatch if ANY" blocks with one ordered table; dispatch rows always precede skip rows so dispatch triggers override any skip indicator
- `new_user_facing_behavior` now has an objective definition (new exports, HTTP routes, CLI flags, UI components, public classes) with a concrete detection command
- New slice JSON fields: `test_skip_reason` (enum: `quick_mode_trivial`, `pure_refactor`, `infra_only`, `docs_only`) and `test_skip_evidence`

### New Features

**Decisions Journal (`.devline/decisions.md`)**
- Append-only institutional memory for consequential calls: PRD resolutions, scope cuts, architectural picks, reviewer overrides, stuck-slice choices
- Canonical spec + write helper in `skills/_shared.md` → "Decisions Journal"
- Write triggers added to `phase-0-prd.md` (on PRD approval) and `phase-3-execution.md` (on reviewer-finding override)
- Read into `dl-plan` Phase 1.1 (skip re-litigating settled questions) and `dl-review` Phase 1/3 (auto-drop findings matching prior overrides)

**Slice retry: programmatic prior-cycle assembly**
- `phase-3-execution.md` retry loop now builds the "Prior Work" block via `jq` against `slice-N.json` instead of asking the model to reconstruct it from conversation memory
- Eliminates the recurring bug where retry cycles silently dropped fields (`concerns`, `review_findings.required_changes`) and re-made the same mistakes

**`/dl-review`: parallel per-check Tasks**
- Phase 2 restructured to dispatch one subagent Task per active check (default checks + each `config.json.review_checks` entry) in a single message
- Each check returns a JSON array; Phase 3 merges, de-dups, filters against decisions.md, and synthesises the verdict
- Wall-clock review time on N-check projects approaches single-check time; each check gets its own bounded context window

---

## [0.6.0] — 2026-05-17

### New Features

**Observability: Session Event Log**
- New `bin/dl-log` script — appends structured JSONL events to `.devline/sessions/session.jsonl`
- Events include: skill name, phase, step, elapsed_ms, tokens_est, and arbitrary meta
- Status line printed to stderr after each event (visible in terminal, not in AI context)
- Skills use `dl-log` to record phase transitions for auditing long sessions
- `_shared.md` updated with `## Session Event Log` section defining the 8 standard events and usage directive

**Debugging: 4-Phase Investigation Methodology**
- `dl-fix/SKILL.md` fully rewritten with structured 4-phase approach:
  - Phase 1: Root Cause Investigation (reproduce, check recent changes, trace component boundaries)
  - Phase 2: Pattern Analysis (find working examples, compare against references)
  - Phase 3: Hypothesis & Testing (single hypothesis, one variable at a time)
  - Phase 4: Implementation (TDD — failing test first, fix at root cause not symptom)
  - Phase 4.5: Architectural Escalation — if ≥3 cycles fail, surfaces all hypotheses and escalates to user
- Added **bail-to-spec** mechanism: when a bug reveals feature-level scope, `/dl-fix` stops and routes to `/dl-feature` instead of silently expanding
- All debugging phases include rationalization prevention tables and red flags

**Token Budget Awareness**
- `_shared.md` updated with `## Token Budget Awareness` section:
  - Estimation heuristics per context type (memory.md, skill file, agent dispatch)
  - Budget warnings at 60% (T2 Inform) and 80% (T2 Warn with pruning recommendation)
  - Smart context pruning directives: what to drop first when budget is tight
  - Elapsed time tracking directive — skills log time per step/phase
- Skills use `dl-log --tokens <estimate>` to track token consumption per phase

**Memory Sync: Branch Switch + Completion**
- New `hooks/post-checkout` — fires on branch switch (not file checkout), triggers background memory regen
- `dl-init/SKILL.md` Step 4 updated to install both `post-commit` and `post-checkout` hooks
- `dl-sync/SKILL.md` When to Call table updated with branch switch and feature completion entries
- `_shared.md` updated with `## Memory Sync Points` section defining all trigger points

**Greenfield PRD Mode**
- `phase-0-prd.md` now detects whether the project is existing or greenfield (new project from scratch)
- Greenfield mode asks 8 structured questions: vision → target users/personas → key user stories → stack selection → architecture blueprint → MVP scope → success criteria → constraints
- Distinct PRD templates for existing features vs. greenfield projects
- Mode detection table with clear signals (no `.devline/`, no codebase, "build from scratch" language)

**Two-Stage Review (Phase 5)**
- `phase-5-review.md` rewritten to two stages:
  - Stage 1: Spec Compliance — new `spec-reviewer.md` agent checks PRD requirements are met, no scope creep
  - Stage 2: Code Quality — existing `final-review.md` checks architecture, consistency, maintainability
- Each stage has independent PASS/FAIL with retry loops (max 2 cycles each before escalation)
- Stage 2 only runs after Stage 1 passes — prevents reviewing code that doesn't meet spec

**Web Style & Accessibility Skill**
- New `skills/web-style/` skill with full 6-dimension audit framework:
  - `SKILL.md` — invocation, iron law, output format (6-dimension table + top 3 fixes)
  - `accessibility-wcag-aa.md` — WCAG 2.1 AA contrast ratios, 8 ARIA patterns, focus management, keyboard navigation, color-not-alone rule
  - `design-system.md` — design tokens, spacing scale (8/12/16/24/32/48px), typography scale, dark mode patterns
  - `responsive-design.md` — mobile-first at 320px, touch targets ≥44px, breakpoints, no horizontal scroll
  - `anti-patterns.md` — CSS smells (hardcoded colors, arbitrary spacing, !important), HTML smells (div as button, skipped headings), animation smells
- Auto-triggered by `/dl-feature` when web stack detected
- Registered in `using-devline/SKILL.md` routing table

**Phase 6 Completion: Discard + Cleanup**
- `phase-6-completion.md` updated with:
  - Option D: Discard — requires typed "discard" confirmation, then force-deletes branch
  - Base branch auto-detection (`main`/`master`)
  - Worktree + branch cleanup table covering all four options (merge/PR/keep/discard)
  - Artifact cleanup: session logs older than 30 days, archived plans older than 90 days
  - Step 7: active plan symlink cleanup

**Red Flags Tables (Discipline)**
- Added `## Red Flags — STOP` sections to 7 skills that were missing them:
  `dl-init`, `dl-sync`, `dl-plan`, `dl-review`, `dl-benchmark`, `receiving-review`, `writing-skills`
- All skills in Devline now have rationalization prevention + red flags coverage

### Chores

**Rename: Development-Flow → devline**
- Updated all URLs, clone commands, and references to use `github.com/MrInvisib1e/devline`
- Files updated: `README.md`, `.claude-plugin/plugin.json`, `.codex/INSTALL.md`, `.opencode/plugins/devline.js`, `lib/installer/opencode.mjs`
- Deleted `EXPLORATION.md` artifact

**Version bump: 0.5.0 → 0.6.0**
- Updated in `package.json`, `.claude-plugin/plugin.json`, `bin/dl-init`

### Summary of commits

| SHA | Work stream | Description |
|-----|-------------|-------------|
| `e9468ba` | WS2 | feat(debugging): rewrite dl-fix with 4-phase methodology + bail-to-spec |
| `3110500` | WS7 | feat(completion): add Discard option, worktree/artifact cleanup to Phase 6 |
| `28fce38` | WS8 | feat(prd): add greenfield project mode to phase-0-prd |
| `e4f7116` | WS9 | feat(web-style): add web styling + accessibility audit skill |
| `f91a845` | WS1 | feat(observability): add dl-log session event logger and _shared.md directive |
| `df6ef56` | WS3 | feat(tokens+memory): add token budget awareness and memory sync points to _shared.md |
| `9f7d918` | WS5 | feat(memory): post-checkout hook, dl-init installs both hooks, dl-sync updated |
| `f37a462` | WS4a | feat(discipline): add Red Flags tables to 7 skills |
| `f650874` | WS4b | feat(review): two-stage review — spec compliance then code quality |
| `d07b597` | WS6 | chore(rename): Development-Flow → devline, bump version to 0.6.0 |

---

## [0.5.0] — Prior release

Initial public release. Core skill library: dl-init, dl-feature (6 phases), dl-fix, dl-review, dl-plan, dl-sync, dl-verify, dl-benchmark, tdd, worktrees, receiving-review, writing-skills. T1/T2/T3 autonomy model. codebase-memory-mcp integration. Multi-platform support (Claude Code, OpenCode, Gemini CLI, Cursor, Codex).
