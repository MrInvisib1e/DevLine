# DevFlow Changelog

All notable changes to the DevFlow spec suite are documented here.

Format: `[Version] — YYYY-MM-DD`

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
