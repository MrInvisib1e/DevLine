# DevFlow Changelog

All notable changes to DevFlow are documented here.

Format: `[Version] — YYYY-MM-DD`

---

## [3.0] — 2026-05-04

### Added
- SQLite graph store (`graph.db`) — replaces flat JSON + jq pipeline; WAL mode, indexed edges
- `bin/df-migrate` — idempotent migration from nodes.json/edges.json to graph.db
- `bin/lib/ts-extract` — tree-sitter AST extraction helper for 20+ languages (with regex fallback)
- `bin/df-explain` — `--rank` (PageRank), `--diff <sha1> <sha2>`, `--budget <tokens>` flags; default no-arg is now rank mode
- Content-hash caching (`cache/content-hashes.json`) — skips unchanged files on sync
- `df-sync --quick` — tree-sitter only, no AI calls; used by post-commit hook (~100ms)
- `skills/_shared.md` — shared autonomy tier definitions (T1/T2/T3), SIF format rules, unified status model
- `skills/using-devflow/SKILL.md` — bootstrap skill for session-start injection
- `skills/feature/agents/prompts/` — structured prompt templates with slot-filling for all 5 agents
- `skills/feature/agents/output-validation.md` — 8-check validation pipeline with issue fingerprinting
- Plugin manifests for Claude Code, Cursor, Gemini CLI, OpenCode, Codex (`CLAUDE.md`, `GEMINI.md`, `hooks/`, `.claude-plugin/`, `.cursor-plugin/`, `gemini-extension.json`, `.codex/INSTALL.md`)
- `package.json` with `bin` field for npm-installable CLI
- Tiered `memory.md` rendering — top 50 PageRank nodes, edge summary, 2500 token cap
- Batch git log for staleness detection (single `git log --name-only` replaces per-node calls)

### Changed
- **Autonomy model** — 3-tier T1/T2/T3 replaces blanket "propose 2-3 options" guard rail
  - `/init` 4–5 gates → 1 (final summary only)
  - `/feature` ~12 gates → 3 (PRD, slices, completion)
  - `/fix` 3 gates → 1 (exhausted cycles)
  - `/review`, `/mem-sync`, `/verify` → 0 gates (fully autonomous)
- **Unified status model** — executors: `DONE|BLOCKED`, reviewers: `PASS|FAIL`; `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, `APPROVED`, `CHANGES_REQUESTED` eliminated
- **Phase 3 state tracking** — `steps[N].done=true` written after each slice, plan.md updated per batch
- **Phase 4** — contract manifest + static validation before integration testing
- **Phase 6** — self-contained completion flow (no external `finishing-a-development-branch` dependency); post-completion verification gate
- **Resume logic** — reads `steps[].done` (now actually written); Resume Point Decision Table
- **All 7 skills** — SIF format, WHY-grounded iron laws, decision tables, scope fences, checkpoint assertions
- Memory storage — SQLite primary, JSON exported on demand only
- `post-commit` / `post-checkout` hooks — now use `df-sync --quick` instead of full sync

### Removed
- `InitialSpec.md` — superseded by `docs/specs/2026-05-04-devflow-v3-design.md`
- Hardcoded `Base directory` path from `skills/init/SKILL.md`

---

## [2.0] — 2026-04-29

### Added
- §11a: DevFlow self-testing strategy (bats for scripts, scenario files for skills)
- §11b: Performance & scale budget (sync cost, memory size, AI call frequency, graph traversal)
- §11c: Rollback & undo mechanisms (classifier rollback, intent revert, memory snapshot/restore)
- Cross-workspace failure modes table in §7
- PRD mechanical stopping gate (testable acceptance criteria) in §8 Phase 0
- Quick mode (`/feature --quick`) and `/skip-prd` escape hatch in §8 Phase 0
- df-explain name resolution algorithm (exact → case-insensitive → substring) in graph memory spec §8
- Concrete installation spec with CLAUDE.md format, PATH setup, and verification steps in §13
- Spec versioning headers (Version field) on all three spec documents
- This changelog

### Changed
- §8 Phase 0 stopping condition: from "specific, unambiguous answers" to mechanical testable-criterion gate
- §11 df-explain: "exact/fuzzy" → "exact → case-insensitive → substring" with defined algorithm
- §13 Installation: from hand-wavy to concrete CLAUDE.md format and verification steps

---

## [1.0] — 2026-04-29

Initial spec suite:
- `InitialSpec.md` — core design (skills, scripts, memory model, feature flow)
- `docs/superpowers/specs/2026-04-29-graph-memory-design.md` — graph memory (nodes.json, edges.json, df-resolve)
- `docs/superpowers/specs/2026-04-29-devflow-parallel-execution-design.md` — parallel slice execution via worktrees
