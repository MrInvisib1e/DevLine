---
name: devline-plan
description: Brainstorm, research, and produce an implementation plan before writing code
requires: []
triggers_on_complete: []
---

# /dl-plan — Brainstorm → Research → Plan

Turn an idea or requirement into a fully formed implementation plan. Combines brainstorming, research, and planning into one flow.

**Invoked as:** `/dl-plan <task>`, `/dl-plan --brainstorm <idea>`, `/dl-plan --quick <task>`

<iron-law>
Load `skills/_shared.md` before proceeding. T1/T2/T3 tiers assumed throughout.
DO NOT write code or take any implementation action until the plan is approved.
</iron-law>

---

## Hard Gate

```
DO NOT write code or take any implementation action until the plan is approved.
```

---

## Entry Point Detection (T1 Silent)

Before asking questions, assess the input:

| Input Type | Action |
|-----------|--------|
| Clear spec (specific files, APIs, acceptance criteria) | Skip brainstorming → go to Phase 2: Research |
| Vague idea (general description, no specifics) | Start with Phase 1: Brainstorming |
| `/dl-plan --brainstorm <idea>` (explicit) | Force brainstorming mode |
| `/dl-plan --quick <task>` (explicit) | Skip brainstorming AND research tiers → go straight to Phase 3: Plan |
| DEFAULT | Assess: does input have acceptance criteria? Yes → Phase 2. No → Phase 1. |

---

## Phase 1 — Brainstorming (if needed)

### 1.1 Explore project context (T1 Silent)

Read `.devline/memory.md`. Run `dl-explain --rank --budget 20` to identify top nodes.

**Also read `.devline/decisions.md` if it exists.** Filter to entries whose `Scope:` field overlaps the modules implied by the user's task. Use prior PRD/scope/override decisions to:
- Skip clarifying questions whose answer is already on record (don't re-litigate)
- Surface prior `Scope cut:` entries to the user if the new task appears to re-introduce a cut item — ask before silently expanding scope
- Reuse architectural picks (`Convention:` entries) instead of re-debating them

T2 Inform on any match: `[Devline] Found N prior decisions touching this scope — applying.` — because the highest-leverage memory is the answer to a question we've already settled; without surfacing it, every plan starts from zero.

### 1.2 Ask clarifying questions (one at a time)

Ask only what is needed to resolve genuine ambiguity:
- Purpose + constraints
- Success criteria
- Non-goals (YAGNI ruthlessly)

Maximum 4 questions. Stop when you have enough to propose approaches.

### 1.3 Propose 2-3 approaches

Present 2-3 approaches per the rules below:

| Rule | What it means |
|------|---------------|
| Lead with recommended | First option is the recommendation; others are alternatives |
| Concrete | Name actual files and patterns, not abstract descriptions |
| Trade-offs explicit | Each option lists its main upside AND main downside |
| DEFAULT | Recommend the simplest option that meets all stated constraints |

### 1.4 Present design sections

Ask for approval after each section. Scale section depth to feature complexity.

| Section | What to cover |
|---------|--------------|
| Architecture | How this fits into the existing system |
| Components | Which files change and what each is responsible for |
| Data flow | How data moves between components |
| Error handling | Failure modes and recovery |
| Testing | How the change will be verified |
| DEFAULT | Skip sections that don't apply to the current scope |

### 1.5 Write spec document (T3 Gate)

Save to `docs/specs/YYYY-MM-DD-<topic>-design.md`. Commit.

Self-review before saving:
1. Placeholder scan — no TBD, TODO, vague requirements
2. Internal consistency — sections don't contradict each other
3. Scope check — is this one implementable unit?
4. Ambiguity check — any requirement that could be interpreted two ways? Pick one.

```dl:choice
question: Spec saved to `{path}`. Does it look right before we plan?
options:
  - label: Yes, start planning
    description: Spec is correct — proceed to Phase 2
  - label: Change the spec
    description: I'll describe what to update in the spec first
default: Yes, start planning
```

---

## Phase 2 — Research (auto-tiered)

Auto-detect tier from scope:

| Scope | Tier | What to do |
|-------|------|-----------|
| ≤2 files, clear pattern, following existing feature | Quick | Read memory.md + relevant files only |
| Multi-module, known pattern, some uncertainty | Standard | + `dl-explain <relevant symbols>` + read existing docs |
| New subsystem, unknown pattern, no reference | Deep | Dispatch parallel research agents (see below) |
| DEFAULT | Standard | If uncertain about tier, use Standard |

Force tier: `/dl-plan --research quick|standard|deep <task>`

**Deep research — three parallel Tasks (single message, three `Task` calls):**

This is the deep-tier dispatch. The three agents work on disjoint slices of the question, so the orchestrator MUST send all three in one assistant message — never sequentially. — because serializing them defeats the point of the deep tier; the wall-clock budget for deep research only fits if the three Tasks share one window.

**Dispatch contract per Task:**

| Slot | Value |
|------|-------|
| `subagent_type` | `general-purpose` |
| `description` | `dl-plan research: <focus>` (≤7 words; one of `codebase`, `docs`, `coupling`) |
| `prompt` | The contents of the corresponding role file (`skills/dl-plan/agents/research-{codebase,docs,coupling}.md`) + the user's task description + the relevant memory.md excerpt + (for Agent C) the orchestrator's candidate affected-files list |
| `output contract` | Each agent returns ONLY a JSON object: `{summary, evidence: [{file, lines, note}], open_questions: [...]}`. The role file is the source of truth for the contract. |

**Parallelism rule:** All three Tasks dispatched in a single message. Wait for all three. Do not gate any on the others.

### 2.5 Synthesis (T1 Silent)

Once all three reports return:

1. **Merge evidence:** union the three `evidence` arrays, dedup by `(file, lines)`.
2. **Aggregate open questions:** collect all `open_questions` from all three reports into one list.
3. **Resolve before Plan Generation:** if `open_questions` is non-empty, present them as a single `dl:choice` (one question at a time if multiple are blocking). Do NOT proceed to Phase 3 with unresolved structural questions.
4. **Write to plan-draft:** the merged evidence becomes the "Reference Pattern" + "Co-change coupling" sections of the eventual plan.md.

— because three parallel agents without a synthesis step produce three disjoint reports the planner has to re-merge in conversation memory — wasting context and risking dropped findings.

**Co-change coupling fallback (Standard tier only):** Run `dl-explain --node <file>` on affected files to check which files historically change together. Files with `FILE_CHANGES_WITH` edges are likely coupled — include them in the plan. (Deep tier covers this via Agent C; Standard tier still needs this lightweight pass.)

---

## Phase 3 — Plan Generation

### 3.1 Map affected nodes (T1 Silent)

Run `dl-explain <component>` for each module affected. Identify reference feature from memory.md — a similar existing feature to use as a pattern.

### 3.2 Build plan document

Structure:
```markdown
## Affected Modules
- Backend: [exact file paths]
- Frontend: [exact file paths]
- Database: [migrations if any]

## Reference Pattern
[similar existing feature from memory.md — which file/function to follow]

## Tasks
### Task N: [descriptive name]
Files: [exact paths — must exist or be created in a prior task]
Steps:
- [ ] Write failing test
- [ ] Run test, verify it fails
- [ ] Implement minimal code
- [ ] Run test, verify it passes
- [ ] Commit
```

Rules for tasks:
- Exact file paths always (verify they exist or will be created earlier)
- Complete code in every code step — no "similar to Task N", no "add validation"
- TDD order: failing test first, implement second
- Frequent commits (after each passing test)
- No placeholders (no TBD, TODO, "add error handling")

### 3.3 Write to `.devline/plans/YYYY-MM-DD-<slug>/plan.md`

```dl:choice
question: Does this plan look right?
options:
  - label: Yes, proceed with implementation
    description: Plan is approved — ready to execute
  - label: Change something
    description: I want to adjust the plan before proceeding
default: Yes, proceed with implementation
```

After approval: T2 Inform — "Plan saved to `.devline/plans/{path}/plan.md`. Use `/dl-feature` to execute."

---

## Architectural Guidance

Before proposing a plan, verify these questions are answered:

| Question | Why it matters |
|----------|---------------|
| What is the smallest change that achieves the goal? | Over-engineering adds risk and review friction |
| Which existing pattern in the codebase does this follow? | Consistency reduces review friction and onboarding cost |
| What can break as a side effect? | Plan for rollback and blast radius |
| Is this change reversible? | Prefer reversible changes; flag irreversible ones explicitly |
| What does this NOT touch? | Explicit out-of-scope prevents scope creep during execution |
| Where is the nearest working example? | Reference patterns produce more accurate plans than abstractions |

CHECKPOINT: "[Devline] dl-plan architectural guidance checked before plan generation"

---

## ADR Integration

If Phase 1 produced architectural decisions worth preserving:
```bash
codebase-memory-mcp cli manage_adr '{"action":"create","title":"...","decision":"...","rationale":"..."}'
```

T2 Inform: "ADR saved to knowledge graph — will appear in future `get_architecture` calls."

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Task is clear, skip brainstorming" | Auto-detection handles this. Trust the table. |
| "I know the answer, skip research" | Hidden coupling shows up in co-change edges. Check. |
| "TDD adds steps to the plan" | TDD steps take 5 minutes. Debugging untested code takes hours. |
| "Plan is too long" | Shorter plans skip steps. They get stuck. |
| "Similar to Task N" | Always write the full code. The executor reads tasks independently. |

## Red Flags — STOP

- Writing a plan without brainstorming first
- Skipping research phase because "I know this domain"
- Plan steps that say "implement X" without showing code
- Referencing types/functions not defined in any task
- "TBD", "TODO", or "fill in later" anywhere in the plan
- Proceeding to execution without user approval

**Stop. Re-read the plan. Fill in every gap.**
