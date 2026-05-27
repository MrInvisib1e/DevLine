# Devline Shared Definitions

## Autonomy Tiers

Every action in every Devline skill falls into one of three tiers.

### T1 — Silent
**Do it. No output. No waiting.**
Use when: mechanical, reversible, judgment-not-required.
Examples: stack detection, workspace name derivation, obvious file classification,
cache checks, git log reads, staleness checks that pass.
Log all T1 actions to session audit list (in working memory only, not printed).

### T2 — Inform
**Do it. Print one-line summary. Do not wait.**
Use when: judgment with a clear default, reversible, user benefits from knowing.
Format: `[Devline] <action taken>: <result>`
Examples:
- "Memory was stale — synced to abc123"
- "Targeting auth-service node"
- "Reading 4 files: x, y, z, w"
- "dl-sync failed (exit 1) — proceeding with stale memory"

### T3 — Gate
**Present options. Wait for user input. Do not proceed.**
Use when: irreversible, high-stakes, genuinely ambiguous, or the action permanently
changes something the user owns (memory write, merge, commit).
Format: present the decision clearly, offer concrete options or Y/N. Always wait.

> **T3 gates use the Devline Interaction Protocol.** When presenting choices, follow `skills/_interaction-protocol.md`: use `AskUserQuestion` if available, otherwise render `[A] [B] [C]` text format.

## Classification Table

| Reversible? | Judgment required? | High-stakes? | Tier |
|-------------|--------------------|--------------|------|
| Yes         | No                 | No           | T1   |
| Yes         | Yes (clear default)| No           | T2   |
| Yes         | Yes (ambiguous)    | No           | T2 (state assumption, proceed) |
| No          | Any                | No           | T3   |
| Any         | Any                | Yes          | T3   |

**High-stakes = permanently modifies memory, git history, or user-owned files.**

## Session Audit Log

Every T1 action MUST be logged to the AI's in-session working memory as:
`[T1] <step>: <action>`

This list is available on request but is NOT printed automatically.
It enables post-session audit of what was done silently.

## Session Event Log

Skills SHOULD call `dl-log` at key lifecycle points. This is T1 Silent — never blocks.

| Event | When | Example |
|-------|------|---------|
| `skill_start` | Skill begins | `dl-log skill_start --skill dl-feature` |
| `phase_start` | Phase begins | `dl-log phase_start --skill dl-feature --phase 0` |
| `phase_end` | Phase completes | `dl-log phase_end --skill dl-feature --phase 0` |
| `gate_hit` | T3 gate reached | `dl-log gate_hit --skill dl-feature --step "PRD approval"` |
| `agent_dispatch` | Agent dispatched | `dl-log agent_dispatch --step "slice-impl" --meta '{"slice":"auth"}'` |
| `agent_done` | Agent returns | `dl-log agent_done --step "slice-impl" --meta '{"status":"DONE"}'` |
| `error` | Error occurs | `dl-log error --skill dl-fix --meta '{"code":"E04"}'` |
| `skill_end` | Skill completes | `dl-log skill_end --skill dl-feature` |
| `agent_timeout` | Per-agent watchdog tripped | `dl-log agent_timeout --skill dl-feature --meta '{"role":"impl","deadline_ms":600000,"cycle":1}'` |
| `config_migrated` | Config shape upgrade applied | `dl-log config_migrated --skill dl-sync --meta '{"migration":"review_checks_v2"}'` |

### Event schema

Every event line is a JSON object with these keys (None values stripped):

| Field | Type | Source |
|-------|------|--------|
| `ts` | ISO timestamp | Set by `dl-log` |
| `event` | string | First positional arg |
| `skill` | string | `--skill <name>` |
| `phase` | int | `--phase <n>` |
| `step` | string | `--step <desc>` |
| `tokens_est` | int | `--tokens <n>` |
| `feature` | string | env `DEVLINE_FEATURE` (orchestrator sets for the run) |
| `slice` | string | env `DEVLINE_SLICE` (set inside a slice dispatch) |
| `meta` | object | `--meta <json>` |

— because the previous schema had no way to correlate events back to a feature or slice; downstream tools had to grep prose `step` strings, which broke whenever wording drifted.

### Retention & index

- `.devline/sessions/session.jsonl` is the active log.
- When it exceeds 1000 lines, `dl-log` rotates it to `session-YYYYMMDD-HHMMSS.jsonl` and starts a fresh `session.jsonl`. No manual rotation needed.
- 30-day file-level cleanup runs from Phase 6 (`find -mtime +30 -delete`).
- `.devline/sessions/index.json` maps `feature-slug → {start_ts, end_ts, files:[{path, line_start, line_end, event_count}]}`. Rebuilt by `bin/dl-log-index`, called from `/dl-sync` Step 2.7 and Phase 6 Artifact Cleanup. Authoritative read source for `/dl-explain` and `/dl-verify` when answering "what happened in feature X" — never grep the JSONL files directly.

## Unified Status Model

| Agent Type | Valid Statuses |
|------------|---------------|
| Executor (implementation, test agents) | `DONE` \| `BLOCKED` |
| Reviewer (slice-review, integration, final-review) | `PASS` \| `FAIL` |

### Orchestrator Decision Table

| Agent Result | Tests Pass? | Action |
|--------------|------------|--------|
| `DONE` | yes | → send to reviewer |
| `DONE` | no | → mark FAIL, retry (max 3) |
| `BLOCKED` | — | → log reason, mark stuck, T3 gate if max retries |
| `PASS` | — | → proceed to next phase |
| `FAIL` | — | → retry with findings (max 3) |
| 3 retries exhausted | — | → mark stuck, T3 gate |

## Skill Chaining

Each skill declares its dependencies in YAML frontmatter:
- `requires:` — skills that MUST run before this skill (unconditional)
- `requires_if:` — skills that MUST run only when a runtime condition holds. See [Conditional Dependencies](#conditional-dependencies-requires_if) below.
- `triggers_on_complete:` — skills that SHOULD run after this skill

The AI reads frontmatter at skill start and announces the chain.

## Structured Instruction Format (SIF) Rules

All Devline skills follow SIF. Rules:

1. **No prose paragraphs.** Use tables, numbered lists, and code blocks. Never explain in sentences what a table can say.
2. **Decision tables over prose.** Every conditional logic block is a table with columns: Condition | Action | DEFAULT.
3. **DEFAULT: on every decision table.** Every table must have a DEFAULT row to prevent the AI freezing on an unhandled case.
4. **Checkpoint Assertions.** After each critical step, print: `CHECKPOINT: "[Devline] <step completed>"`. This forces step completion before proceeding.
5. **WHY-Grounding.** Every critical rule ends with `— because <consequence>`. Lets the model apply the principle to edge cases.
6. **Scope Fences.** Before any implementation step: `<scope>EDIT: only <files>. DO NOT: refactor, add features, update deps</scope>`.
7. **HALT with exact text.** Failure conditions end with: `HALT. Print exactly: "<message>". Do not attempt recovery.`
8. **Rationalization table placement.** "You Will Be Tempted To" table appears AFTER the steps, not before.
9. **XML semantic wrapping.** Use `<iron-law>`, `<scope>`, `<checkpoint>` tags for critical blocks.
10. **Context placement.** Long documents before the task instruction. Steps last in the document.

## Precision Techniques Summary

| Failure Mode | Technique | Format |
|-------------|-----------|--------|
| Skips steps | Checkpoint Assertion | `CHECKPOINT: "[Devline] Step N done: <result>"` |
| Misinterprets | WHY-Grounding | `Rule X. — because <consequence>` |
| Drifts | Scope Fence | `<scope>EDIT: X only. DO NOT: Y</scope>` |
| Improvises | HALT with exact text | `HALT. Print exactly: "<msg>"` |
| Skips steps | State Machine Dispatch | Table: Phase → File → When |

---

## config.json Schema

Generated by `dl-init`, read by all skills. Located at `.devline/config.json`.

```json
{
  "service": "project-name",
  "mode": "project",
  "stack": {
    "runtime": "nodejs | dotnet | python | go | rust | ruby",
    "frontend": "sveltekit | nextjs | null"
  },
  "last_synced": "<git HEAD SHA>",
  "classifiers": [
    { "pattern": "src/domain/**", "type": "entity" }
  ],
  "review_checks": [
    { "name": "naming", "severity": "WARNING", "convention": "Symbol names follow the patterns in memory.md", "evidence_hint": "grep additions for new exported symbols" },
    { "name": "test-coverage", "severity": "WARNING", "convention": "Every changed source file has a corresponding test change in the diff", "evidence_hint": "git diff --name-only filtered to source vs test paths" },
    { "name": "unclassified", "severity": "NOTE", "convention": "New files are recognised by at least one classifier in config.json", "evidence_hint": "git diff --diff-filter=A --name-only" },
    { "name": "impact-radius", "severity": "NOTE", "convention": "Inbound callers of changed symbols are addressed or noted", "evidence_hint": "dl-explain --impact for current diff" },
    { "name": "dead-code", "severity": "WARNING", "convention": "Diff does not introduce new zero-caller functions", "evidence_hint": "dl-explain --dead-code" },
    { "name": "clone-detection", "severity": "NOTE", "convention": "Diff does not introduce SIMILAR_TO edges with score > 0.8", "evidence_hint": "dl-explain --clones" }
  ],
  "auto_skills": [
    { "trigger": "regex-pattern", "skill": "skill-name" }
  ],
  "quality_hooks": {
    "lint": "npx eslint .",
    "format": "npx prettier --write .",
    "typecheck": "npx tsc --noEmit"
  }
}
```

### Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `service` | string | Project name (from git remote or directory) |
| `mode` | `"project"` \| `"orchestrator"` | Single-project or multi-project root |
| `stack.runtime` | string | Auto-detected runtime |
| `stack.frontend` | string \| null | Auto-detected frontend framework |
| `last_synced` | string | HEAD SHA at last successful memory write |
| `classifiers` | array | Per-project file classification overrides |
| `review_checks` | array of objects | Which checks `/dl-review` runs. Each entry: `{name, severity, convention, evidence_hint?}`. `severity ∈ {BLOCKING, WARNING, NOTE}`. `convention` is the one-sentence rule the per-check subagent reads as its prompt. `evidence_hint` (optional) seeds the check's first investigation step. Bare-string entries from pre-0.7 configs are auto-migrated by `/dl-sync` (see "Config Migration"). |
| `auto_skills` | array | Skill auto-activation rules (regex trigger → skill name) |
| `quality_hooks` | object | Commands for `dl-check` (lint/format/typecheck) |
| `test_cmd` | string \| absent | Pre-flight build check command. **Fallback rule:** if absent or empty string, skills MUST skip the pre-flight build check with a T2 Inform message — not halt. Default: skip gracefully. — because skills that read `test_cmd` had no documented fallback, causing inconsistent behavior across projects that haven't configured a test command. |

### Modes

| Mode | Created by | `.devline/` location | Multiple active features? | Memory |
|------|-----------|---------------------|--------------------------|--------|
| `project` | `dl-init` (default) | git root | No — one at a time | Single `memory.md` |
| `orchestrator` | `dl-init --orchestrator` | parent dir | Yes — unlimited per level | Aggregates child `memory.md` files |

### Orchestrator Behavior Rules

1. **Multiple active features at orchestrator root:** Allowed. The active plan check that halts in `project` mode is skipped.
2. **Multiple active features at child level:** Also allowed — child projects behave independently; the orchestrator root observes but does not modify child `.devline/` directly.
3. **Completed features never shown:** A plan is complete if `Status` in plan.md contains `COMPLETED` or `ABORTED`, or if it is in the `archive/` subdirectory.
4. **Child project independence:** Child projects work identically with or without an orchestrator root above them.
5. **Git-optional at orchestrator root:** `last_synced` falls back to ISO timestamp if no git repo at root. Child projects still use their own git state.

## Token Budget Awareness

### Estimation

Skills SHOULD estimate token consumption at key points using this heuristic:

| Content | Estimated Tokens |
|---------|-----------------|
| memory.md | ~2,500 |
| Plan file (typical) | ~3,000–5,000 |
| Source file (per file) | ~500–2,000 |
| Agent prompt (per dispatch) | ~1,500–3,000 |
| Skill file (per load) | ~500–1,500 |

### Budget Warnings

| Context Used | Action |
|-------------|--------|
| < 60% | Normal operation |
| 60–80% | T2 Inform: "[Devline] Context at ~{N}% — consider pruning completed phases" |
| > 80% | T2 Inform: "[Devline] Context at ~{N}% — pruning stale context now" + auto-prune |
| DEFAULT | Normal operation |

### Smart Context Pruning Directives

When context exceeds 60%, skills SHOULD:

1. **Drop completed phase details** — keep only the phase status line, not the full content
2. **Summarize agent outputs** — replace full agent output with 2-3 line summary
3. **Keep active phase + plan.md + memory.md** — these are always needed
4. **Drop file contents already committed** — git has them, context doesn't need them
5. **Never drop:** Iron Laws, behavior contracts, current hypothesis, active slice spec

### Elapsed Time Tracking

Skills SHOULD track elapsed time per step/slice/branch. Report elapsed time in T2 Inform messages when a step takes >30 seconds.

## Memory Sync Points

Memory is synced automatically at these points:

| Trigger | Mechanism | Blocks? |
|---------|-----------|---------|
| After commit | `post-commit` hook (background) | No |
| Branch switch | `post-checkout` hook (background) | No |
| Feature completion (Phase 6) | `dl-init --write-memory --force` | Yes (verification) |
| Manual | `/dl-sync` | No |
| Stale memory detected | Pre-flight in dl-fix, dl-feature | No (auto-sync) |

Skills SHOULD NOT call `dl-init --write-memory` directly except in Phase 6 completion. Trust the hooks.

## Pre-Flight Staleness Check

Canonical definition. Skills that need a fresh memory before proceeding reference this section instead of inlining the bash. — because four skills previously duplicated this block with wording drift; one source of truth prevents the drift.

```bash
LAST=$(jq -r '.last_synced // ""' .devline/config.json 2>/dev/null)
HEAD=$(git rev-parse HEAD)
if [ "$LAST" != "$HEAD" ]; then
  # stale — run dl-sync (T1 Silent), then T2 Inform on success
  /dl-sync
fi
```

Both `last_synced` and HEAD are git commit SHAs. Stale = they do not match exactly. — because without an explicit comparison, "if stale" is ambiguous and the model may rationalize "close enough" and skip the sync.

| Outcome | Tier | Output |
|---------|------|--------|
| `LAST == HEAD` | T1 Silent | none |
| `LAST != HEAD`, sync succeeds | T2 Inform | `[Devline] Memory was stale — synced to {HEAD}` |
| sync fails (exit ≠ 0) | T2 Inform | `[Devline] dl-sync failed (exit {N}) — proceeding with stale memory` |
| DEFAULT | T1 Silent | none |

## Conditional Dependencies (`requires_if:`)

Frontmatter may declare `requires_if:` for dependencies that should run only when a runtime condition holds.

```yaml
requires: []
requires_if:
  dl-sync: memory_stale
```

| Condition | Meaning |
|-----------|---------|
| `memory_stale` | `config.json.last_synced != git rev-parse HEAD` |
| DEFAULT | Treat as unconditional `requires:` |

`requires:` is for unconditional dependencies (always run). `requires_if:` is for conditional ones (run only when the condition evaluates true at skill start). — because declaring conditional deps in `requires:` overstates the contract and causes future tooling that reads the chain graph to force-run skills that the runtime would skip.

## Auto-Classification

Skills MAY silently downgrade the depth of user interaction (number of questions, phases run) based on signals in the user's input. Auto-classification is T1 Silent for the detection itself; the resulting downgrade is announced with a T2 Inform so the user can interrupt if misclassified.

| Element | Rule |
|---------|------|
| Detection | T1 Silent — pattern-match against description (regex, length, file-pattern hints) |
| Downgrade announcement | T2 Inform: `[Devline] Auto-classified as {label} — using {mode}.` |
| User override | Re-running with explicit mode flag (e.g. `/dl-feature quick …`) bypasses auto-classification |
| DEFAULT | No downgrade; use full mode |

— because forcing the user to type a mode flag for obviously-trivial work creates friction; silent classification with a visible inform line preserves correction-ability without ceremony.

## Scope Fence Verbs

`<scope>` blocks declare what an agent is permitted to do. Two legal verbs:

| Verb | Meaning | Example |
|------|---------|---------|
| `EDIT:` | Permitted to read AND modify the listed files | `<scope>EDIT: src/auth/*.ts. DO NOT: refactor, add deps</scope>` |
| `READ:` | Permitted to read only — no writes | `<scope>READ: src/. DO NOT: edit, write any file</scope>` |
| DEFAULT | Assume `READ:` if unspecified |

— because read-only analysis skills and write-capable execution skills both need scope fences, but conflating the verbs hides the read-vs-write distinction that matters for safety.

## Decisions Journal

Canonical definition. `.devline/decisions.md` is an append-only log of consequential calls made during Devline runs: PRD resolutions, scope cuts, architectural picks, and review-finding overrides. It is the project's institutional memory across features — without it, every `/dl-plan` and `/dl-review` re-litigates settled questions.

**Location:** `.devline/decisions.md` (created on first append; never regenerated wholesale).

**Entry format — one block per decision, newest at top:**

```markdown
## YYYY-MM-DD — <short title>

- **Context:** <feature-slug or skill that produced this> · <branch>
- **Decision:** <one sentence — what was chosen>
- **Rationale:** <one or two sentences — why; cite alternative rejected if any>
- **Scope:** <files / modules / convention affected, or "global">
```

**Write triggers (mandatory):**

| Trigger | Producer | Title prefix |
|---------|----------|--------------|
| PRD approved | `phase-0-prd.md` | `PRD: <feature>` |
| Scope cut / out-of-scope item explicitly dropped | `phase-0-prd.md`, `phase-2-slices.md` | `Scope cut: <item>` |
| Reviewer finding overridden ("not a finding" or "ship anyway") | `phase-3-execution.md`, `dl-review` | `Override: <finding>` |
| Stuck-slice user choice (manual / remove / abort) | `phase-3-execution.md` | `Stuck-slice: <slice>` |
| Convention added or changed mid-feature | `dl-sync`, `dl-review` | `Convention: <name>` |

**Read triggers:**

| Reader | When | Use |
|--------|------|-----|
| `/dl-plan` Phase 1 | Always | Avoid re-asking previously-resolved scope/architecture questions |
| `/dl-review` Phase 1 | Always | Skip flagging items previously overridden with same context |
| `/dl-feature` Phase 0 | If existing-project mode | Pre-fill PRD answers from prior decisions on same module |

**Append helper (use this exact bash to avoid format drift):**

```bash
DECISIONS=.devline/decisions.md
[ -f "$DECISIONS" ] || printf '# Decisions Journal\n\nAppend-only. Newest at top.\n\n' > "$DECISIONS"
# Build the new entry in $ENTRY (caller's responsibility), then prepend:
{ printf '%s\n\n' "$ENTRY"; tail -n +4 "$DECISIONS"; } > "$DECISIONS.tmp" && \
  { head -n 3 "$DECISIONS" > "$DECISIONS.new"; cat "$DECISIONS.tmp" >> "$DECISIONS.new"; } && \
  mv "$DECISIONS.new" "$DECISIONS" && rm "$DECISIONS.tmp"
```

— because a decisions log only earns its keep when entries are uniform enough to grep; freeform notes degrade into a journal nobody reads.

**Never write to decisions.md:**
- Routine status updates (use plan.md / slice JSON)
- Implementation details (use commit messages)
- Anything the codebase itself documents (use code + memory.md)

## Config Migration

`/dl-sync` is the canonical migration point for `.devline/config.json` shape upgrades. Migrations are one-shot, idempotent, and announced via a single T2 Inform.

### Registry of migrations

| ID | Trigger condition | Action |
|----|-------------------|--------|
| `review_checks_v2` | Any entry in `config.json.review_checks` is a bare string | Replace each bare string with its default object from the lookup table below. Unknown names get `{name, severity: "NOTE", convention: "Custom check — define convention in config.json", evidence_hint: ""}` so they remain visible rather than silently dropped. |
| DEFAULT | — | No-op |

### Default `review_checks` lookup table

Same as the seed in `bin/dl-init` and the schema example above. The canonical source is `_shared.md` → "Default config" section. — because three places (template seed, migration table, dl-review consumer) all need the same list and drift between them is the most likely future bug.

### Migration helper (use this exact pattern to avoid drift)

```bash
CONFIG=.devline/config.json
TMP=$(mktemp)
python3 - "$CONFIG" "$TMP" << 'PYEOF'
import json, sys
config_path, tmp_path = sys.argv[1], sys.argv[2]
c = json.load(open(config_path))

DEFAULTS = {
  "naming":          {"severity": "WARNING", "convention": "Symbol names follow the patterns in memory.md", "evidence_hint": "grep additions for new exported symbols"},
  "test-coverage":   {"severity": "WARNING", "convention": "Every changed source file has a corresponding test change in the diff", "evidence_hint": "git diff --name-only filtered to source vs test paths"},
  "unclassified":    {"severity": "NOTE",    "convention": "New files are recognised by at least one classifier in config.json", "evidence_hint": "git diff --diff-filter=A --name-only"},
  "impact-radius":   {"severity": "NOTE",    "convention": "Inbound callers of changed symbols are addressed or noted", "evidence_hint": "dl-explain --impact for current diff"},
  "dead-code":       {"severity": "WARNING", "convention": "Diff does not introduce new zero-caller functions", "evidence_hint": "dl-explain --dead-code"},
  "clone-detection": {"severity": "NOTE",    "convention": "Diff does not introduce SIMILAR_TO edges with score > 0.8", "evidence_hint": "dl-explain --clones"},
}

migrated = False
new_checks = []
for entry in c.get("review_checks", []):
    if isinstance(entry, str):
        migrated = True
        d = DEFAULTS.get(entry, {"severity": "NOTE", "convention": "Custom check — define convention in config.json", "evidence_hint": ""})
        new_checks.append({"name": entry, **d})
    else:
        new_checks.append(entry)
c["review_checks"] = new_checks

if migrated:
    json.dump(c, open(tmp_path, "w"), indent=2)
    print("migrated", file=sys.stderr)
else:
    print("noop", file=sys.stderr)
PYEOF
RESULT=$?
if [ -s "$TMP" ]; then
  mv "$TMP" "$CONFIG"
  dl-log config_migrated --skill dl-sync --meta '{"migration":"review_checks_v2"}' >/dev/null 2>&1 || true
  # T2 Inform: [Devline] config.json migrated: review_checks upgraded to v2 (objects)
fi
rm -f "$TMP"
```

— because string→object migration done by hand in three places will inevitably drift; one centralized helper that any skill can paste-and-run keeps the lookup table singular.
