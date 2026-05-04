# Plan 2: Skill Instruction Quality

**Status:** Ready  
**Depends on:** Plan 1 (T1/T2/T3 definitions in `_shared.md`), Plan 6 (SQLite store for concrete examples)  
**Estimated tasks:** 7  
**Execute after:** Plans 6 and 1

## Context

DevFlow skills use prose instructions that are ambiguous, inconsistently structured, and have scattered conditional logic. This plan rewrites all skills using the Structured Instruction Format (SIF): tables instead of prose, decision tables instead of if/else paragraphs, default actions on every decision point, and precision techniques (checkpoint assertions, scope fences, WHY-grounding, HALT conditions, XML semantic wrapping) that prevent the four AI failure modes (skips steps, misinterprets intent, drifts mid-execution, improvises beyond scope).

Net effect: ~5,950 → ~3,400 tokens total skill footprint (~43% reduction), significantly higher instruction-following accuracy.

## Pre-flight

- [ ] Plan 1 complete: `skills/_shared.md` exists
- [ ] Plan 6 complete: `graph.db` schema established (for concrete examples in skills)
- [ ] No uncommitted changes in `skills/`

## Tasks

### Task 2.1 — Define Structured Instruction Format (SIF)

**File(s):**
- Modify: `skills/_shared.md` — add SIF specification section

**What:**
Add the SIF rules to `_shared.md` so all skill rewrites follow the same format standard.

Append to `skills/_shared.md`:

```markdown
## Structured Instruction Format (SIF)

Rules for all DevFlow skill files:

1. **No prose paragraphs.** Use tables, numbered lists, and code blocks only.
2. **Decision tables, not if/else prose.** Every conditional becomes a table row.
3. **DEFAULT: on every decision point.** The AI never freezes on an unhandled case.
4. **Checkpoint Assertions.** After completing each step, print:
   `CHECKPOINT: "[DevFlow] <step-name>: <result-summary>"`
5. **WHY-grounding on critical rules.** Append `— because <consequence>` to every non-obvious rule.
6. **Scope Fences.** Wrap every agentic action's file scope in `<scope>EDIT: {files}. DO NOT: {prohibited}</scope>`
7. **HALT with exact error text.** `NO → HALT. Print exactly: "<message>". Do not attempt recovery.`
8. **XML semantic wrapping.** Use `<iron-law>`, `<scope>`, `<checkpoint>` tags for parsing anchors.
9. **Context placement.** Long context (files, memory) goes BEFORE the task instruction, not after.
10. **Rationalization Prevention AFTER steps.** The "You Will Be Tempted To" table goes at the end, not the beginning.
```

**Verify:**
```bash
grep "SIF\|Structured Instruction" skills/_shared.md
grep "Checkpoint\|DEFAULT:" skills/_shared.md
```

---

### Task 2.2 — Rewrite fix/SKILL.md with full SIF format

**File(s):**
- Modify: `skills/fix/SKILL.md` (full rewrite using SIF — this skill is the smallest, use as template)

**What:**
Rewrite the entire skill using SIF. This file becomes the reference implementation for the format.

Target structure:
```markdown
---
name: fix
requires: [mem-sync]
triggers_on_complete: [verify]
---

# Skill: fix

<iron-law>
HYPOTHESIS BEFORE CODE. ALWAYS.
— because fixing without a hypothesis causes random code changes that mask root causes.
</iron-law>

## Pre-flight

| Check | Command | On Fail |
|-------|---------|---------|
| DevFlow initialized | `[[ -d .devflow ]]` | HALT. Print: "Run /init first." |
| Memory fresh | run mem-sync | T2 Inform result |
| No conflicts | `git status --porcelain` | T2 Inform: conflicts present |

## Steps

### Step 1 — Node inference [T2]
...
CHECKPOINT: "[DevFlow] Fix: targeting <node> (<file>)."

### Step 2 — Load context [T1]
...
CHECKPOINT: "[DevFlow] Fix: loaded memory + df-explain output."

### Step 3 — Form hypothesis [T2]
...
CHECKPOINT: "[DevFlow] Fix: hypothesis [1/3]: <summary>."

### Step 4 — Cycle: read → fix → test
...

## Decision Table

| Condition | Action |
|-----------|--------|
| Tests pass after fix | → DONE. Run verify. |
| Tests fail, cycle < 3 | → new hypothesis, increment cycle |
| Tests fail, cycle = 3 | → T3 Gate: surface findings |
| No node match found | → T3 Gate: ask developer |
| DEFAULT | → T2 Inform, proceed with best guess |

<scope>
EDIT: only files identified in current hypothesis.
DO NOT: refactor adjacent code, add features, update deps, rename variables.
</scope>

## Guard Rails
[From Plan 1 Task 1.4]

## You Will Be Tempted To
| Temptation | Reality |
|-----------|---------|
| Fix obvious code without hypothesizing first | Obvious fixes mask root causes — hypothesize first |
| Skip df-explain and read files directly | df-explain gives graph context; blind file reads miss dependencies |
| Fix adjacent code that looks broken | Out of scope — log it, fix only what the hypothesis covers |
| Run a 4th cycle | Max 3. If 3 cycles fail, the approach is wrong — escalate |
```

Key changes from current:
- YAML frontmatter with `requires` and `triggers_on_complete`
- `<iron-law>` tag around the iron law
- Decision table replaces scattered if/else prose
- `<scope>` fence is explicit
- "You Will Be Tempted To" placed AFTER steps
- Every step has a CHECKPOINT
- WHY-grounding on key rules

**Why:** fix/SKILL.md is the simplest skill (243 lines). Rewriting it first validates the SIF format before applying to larger skills, and it serves as the reference implementation.

**Verify:**
```bash
grep "requires:\|triggers_on_complete:" skills/fix/SKILL.md
grep "CHECKPOINT:" skills/fix/SKILL.md  # ≥ 3 matches
grep "<iron-law>" skills/fix/SKILL.md
grep "<scope>" skills/fix/SKILL.md
grep "Decision Table" skills/fix/SKILL.md
wc -l skills/fix/SKILL.md  # should be <200 lines (current: 243)
```

---

### Task 2.3 — Rewrite mem-sync/SKILL.md with SIF format

**File(s):**
- Modify: `skills/mem-sync/SKILL.md`

**What:**
Apply SIF to mem-sync. This is the shortest skill (137 lines) and a pure utility — no complex decision logic.

Key changes:
- YAML frontmatter: `name: mem-sync`, no `requires`, `triggers_on_complete: []`
- Replace prose steps with numbered table rows
- Replace "never silently continue" prose with `<iron-law>` tag
- Add single CHECKPOINT after sync completes: `"[DevFlow] Memory: synced to <sha>. N nodes, M edges."`
- Decision table for failure cases (replacing "propose 2-3 options"):

```markdown
## Decision Table

| Condition | Action |
|-----------|--------|
| `df-sync` exits 0 | → T2 Inform result. Done. |
| `df-sync` exits non-0, attempt 1 | → T2 retry: `[DevFlow] df-sync failed — retrying.` |
| `df-sync` exits non-0, attempt 2 | → T2 proceed stale: `[DevFlow] df-sync failed twice — proceeding with stale memory.` |
| `.devflow/` missing | → HALT. Print exactly: "DevFlow not initialized. Run /init first." |
| DEFAULT | → T2 Inform, proceed |
```

**Verify:**
```bash
grep "CHECKPOINT:" skills/mem-sync/SKILL.md
grep "Decision Table" skills/mem-sync/SKILL.md
grep "propose 2-3\|Wait for" skills/mem-sync/SKILL.md  # Expected: 0
wc -l skills/mem-sync/SKILL.md  # should be <100 lines
```

---

### Task 2.4 — Rewrite verify/SKILL.md with SIF format

**File(s):**
- Modify: `skills/verify/SKILL.md`

**What:**
Apply SIF to verify. This is the shortest skill (80 lines).

Key changes:
- YAML frontmatter: `name: verify`, `requires: []`, `triggers_on_complete: []`
- `<iron-law>` tag: "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"
- Replace gate function table prose with a proper decision table
- Add CHECKPOINT: `"[DevFlow] Verify: <N>/<M> checks passed. <result>."`

Gate function table (replaces current prose):
```markdown
## Gate Function Table

| Claim | Run | Confirm |
|-------|-----|---------|
| "slice done" | `test_cmd` | Tests pass. git diff shows changes. |
| "fix applied" | `test_cmd` | Tests pass. Hypothesis file changed. |
| "memory sync" | `df-sync && df-explain` | last_synced = HEAD sha. |
| "feature complete" | `test_cmd + build_cmd + lint_cmd` | All pass. |
| "JSON updated" | `jq . <file>` | Valid JSON. Expected keys present. |
| DEFAULT | run `test_cmd` | Tests pass |
```

**Verify:**
```bash
grep "<iron-law>" skills/verify/SKILL.md
grep "Gate Function Table" skills/verify/SKILL.md
grep "CHECKPOINT:" skills/verify/SKILL.md
wc -l skills/verify/SKILL.md  # should be <80 lines
```

---

### Task 2.5 — Add skill chaining frontmatter to all skills

**File(s):**
- Modify: all 7 `SKILL.md` files — add YAML frontmatter

**What:**
Add YAML frontmatter to every skill file declaring dependencies and triggers. The AI reads frontmatter at skill invocation and enforces chaining.

Frontmatter for each skill:

```yaml
# fix/SKILL.md
---
name: fix
requires: [mem-sync]
triggers_on_complete: [verify]
---

# mem-sync/SKILL.md
---
name: mem-sync
requires: []
triggers_on_complete: []
---

# verify/SKILL.md
---
name: verify
requires: []
triggers_on_complete: []
---

# init/SKILL.md
---
name: init
requires: []
triggers_on_complete: [mem-sync]
---

# plan/SKILL.md
---
name: plan
requires: [mem-sync]
triggers_on_complete: []
---

# review/SKILL.md
---
name: review
requires: [mem-sync]
triggers_on_complete: []
---

# feature/SKILL.md
---
name: feature
requires: [mem-sync]
triggers_on_complete: [verify, mem-sync]
---
```

Add enforcement instruction to each skill's Pre-flight section:
```
CHECKPOINT: "[DevFlow] Chaining: loaded <skill>. Required: <requires>. Will trigger: <triggers_on_complete>."
```

**Why:** Skill chaining is currently described in prose ("invoke mem-sync first"). YAML frontmatter makes it machine-readable and enables automated enforcement rather than relying on AI memory.

**Verify:**
```bash
for f in skills/*/SKILL.md; do
  head -5 "$f" | grep "^---" && echo "$f: has frontmatter" || echo "$f: MISSING frontmatter"
done
grep "requires:" skills/fix/SKILL.md
grep "triggers_on_complete:" skills/fix/SKILL.md
```

---

### Task 2.6 — Fix Phase 3 state tracking

**File(s):**
- Modify: `skills/feature/phases/phase-3-execution.md`

**What:**
Add explicit state tracking instructions to Phase 3 execution. This fixes two verified bugs: (1) `steps[].done` is never written, (2) plan.md is never updated with progress.

Add to Phase 3 after each slice completes:

```markdown
### After each slice agent completes:

1. Write to slice JSON:
   ```bash
   # Mark steps as done in the slice's JSON file
   # .devflow/plans/<plan-slug>/<slice-id>.json
   jq '.steps[N].done = true' slice.json > tmp && mv tmp slice.json
   ```

2. Write progress to plan.md:
   Append to `.devflow/plans/<plan-slug>/plan.md`:
   ```
   | <slice-id> | <status> | <timestamp> | <verdict> |
   ```

3. CHECKPOINT: "[DevFlow] Phase 3: slice <id> → <PASS|FAIL|BLOCKED>. Progress: N/M."
```

Add the DONE/BLOCKED status model (replacing DONE_WITH_CONCERNS):

```markdown
### Agent Status Model

| Agent Type | Valid Statuses |
|------------|---------------|
| Executors (impl, test) | DONE \| BLOCKED |
| Reviewers (slice-review, integration, final-review) | PASS \| FAIL |

**DONE_WITH_CONCERNS is eliminated.** Concerns are logged as T2 Inform messages in agent output. The downstream reviewer decides if they matter.
```

Add orchestrator decision table:

```markdown
### Orchestrator Decision Table

| Executor Result | Tests Pass? | Action |
|----------------|------------|--------|
| DONE | yes | → send to reviewer |
| DONE | no | → FAIL, retry (max 3) |
| BLOCKED | — | → log, continue with next independent slice |
| PASS (reviewer) | — | → proceed to Phase 4 |
| FAIL (reviewer) | — | → retry with findings (max 3) |
| 3 retries exhausted | — | → mark stuck, T3 gate |
| DEFAULT | — | → T2 Inform, retry once |
```

**Why:** The current Phase 3 never writes `steps[].done = true` to slice JSON files, making resume impossible. Adding explicit write instructions after each verdict fixes resume functionality.

**Verify:**
```bash
grep "steps\[N\].done\|done = true" skills/feature/phases/phase-3-execution.md
grep "CHECKPOINT:" skills/feature/phases/phase-3-execution.md
grep "DONE_WITH_CONCERNS" skills/feature/phases/phase-3-execution.md  # Expected: 0
grep "Orchestrator Decision Table" skills/feature/phases/phase-3-execution.md
```

---

### Task 2.7 — Apply SIF tables to remaining skills

**File(s):**
- Modify: `skills/review/SKILL.md` — decision tables for finding routing and convention lookup
- Modify: `skills/plan/SKILL.md` — decision table for domain analysis phase
- Modify: `skills/init/SKILL.md` — decision table for classifier lookup

**What:**
For each skill, identify the largest block of prose conditional logic and convert to a decision table. Full SIF rewrite deferred to future iteration — this task targets the highest-impact conversions only.

**review/SKILL.md:** Convert Phase 2 analysis routing to table:
```markdown
## Analysis Routing Table

| Finding Type | Convention Source | Severity | Action |
|-------------|------------------|----------|--------|
| Contradicts memory.md convention | memory.md direct quote | CRITICAL | Always report |
| Contradicts edge relationship | nodes.json/edges.json | HIGH | Always report |
| Deviates from reference feature pattern | Phase 1 pattern | MEDIUM | Report if diff > 10 lines |
| Style inconsistency | No convention source | LOW | Report only if pattern is explicit |
| No convention found | — | — | Do NOT report (opinion, not convention) |
| DEFAULT | — | LOW | Report with [NO-CONVENTION] tag |
```

**plan/SKILL.md:** Convert domain analysis phase to table:
```markdown
## Domain Analysis Table

| Input | Action |
|-------|--------|
| Feature touches existing module | → load that module's reference patterns |
| Feature creates new module | → identify neighboring modules, load their interfaces |
| Feature touches 3+ modules | → identify shared integration point first |
| DEFAULT | → load top 3 PageRank nodes from df-explain --rank |
```

**init/SKILL.md:** Convert file classifier to a formal lookup table (replacing prose step 5):
```markdown
## Auto-Classifier Table

| Pattern | Classification |
|---------|---------------|
| `*.test.*`, `*.spec.*`, `__tests__/**` | test |
| `*.config.*`, `*.env*`, `tsconfig*`, `vite.config*` | config |
| `*.md`, `*.mdx`, `docs/**` | docs |
| `Dockerfile`, `docker-compose*`, `.github/**/*.yml` | infra |
| `*.sql`, `migrations/**` | data |
| `package.json`, `*.lock`, `go.mod`, `Cargo.toml` | deps |
| `bin/**`, `scripts/**`, `Makefile`, `*.sh` | script |
| DEFAULT | source |
```

**Verify:**
```bash
grep "Analysis Routing Table" skills/review/SKILL.md
grep "Domain Analysis Table" skills/plan/SKILL.md
grep "Auto-Classifier Table" skills/init/SKILL.md
# Verify no prose conditionals replacing these tables:
grep "if.*then.*else\|When.*should" skills/review/SKILL.md | wc -l  # should be <5
```

---

## Verification Gates

After all tasks complete:

- [ ] `skills/_shared.md` has SIF rules appended
- [ ] `fix/SKILL.md` has `<iron-law>`, `<scope>`, decision table, CHECKPOINT, frontmatter
- [ ] `mem-sync/SKILL.md` has decision table, CHECKPOINT, no "propose 2-3"
- [ ] `verify/SKILL.md` has `<iron-law>`, gate function table, CHECKPOINT
- [ ] All 7 skills have YAML frontmatter with `requires:` and `triggers_on_complete:`
- [ ] Phase 3 execution has state tracking instructions (`steps[N].done = true`)
- [ ] Phase 3 has unified DONE/BLOCKED/PASS/FAIL status model
- [ ] `DONE_WITH_CONCERNS` does not appear in any skill file:
  ```bash
  grep -r "DONE_WITH_CONCERNS" skills/  # Expected: 0
  ```
- [ ] All skills have at least 1 CHECKPOINT: `grep -r "CHECKPOINT:" skills/ | wc -l` > 7

## Rollback

```bash
git checkout HEAD -- skills/fix/SKILL.md skills/mem-sync/SKILL.md \
  skills/verify/SKILL.md skills/review/SKILL.md skills/plan/SKILL.md \
  skills/init/SKILL.md skills/feature/SKILL.md \
  skills/feature/phases/phase-3-execution.md
# _shared.md SIF section: manual removal or git checkout
```
