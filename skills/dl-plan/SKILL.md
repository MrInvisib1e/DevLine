# /dl-plan — Brainstorm → Research → Plan

Turn an idea or requirement into a fully formed implementation plan. Combines brainstorming, research, and planning into one flow.

**Invoked as:** `/dl-plan <task>`, `/dl-plan --brainstorm <idea>`, `/dl-plan --quick <task>`

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

### 1.2 Ask clarifying questions (one at a time)

Ask only what is needed to resolve genuine ambiguity:
- Purpose + constraints
- Success criteria
- Non-goals (YAGNI ruthlessly)

Maximum 4 questions. Stop when you have enough to propose approaches.

### 1.3 Propose 2-3 approaches

Present with trade-offs and your recommendation. Lead with recommended option. Be concrete — name the files and patterns involved.

### 1.4 Present design sections

Scale to complexity. Ask for approval after each section. Sections to cover:
- Architecture: how it fits into existing system
- Components: what files change
- Data flow: how data moves
- Error handling: failure modes
- Testing: how it will be verified

### 1.5 Write spec document (T3 Gate)

Save to `docs/specs/YYYY-MM-DD-<topic>-design.md`. Commit.

Self-review before saving:
1. Placeholder scan — no TBD, TODO, vague requirements
2. Internal consistency — sections don't contradict each other
3. Scope check — is this one implementable unit?
4. Ambiguity check — any requirement that could be interpreted two ways? Pick one.

Ask user: "Spec saved to `{path}`. Review it and confirm before we plan."

Wait for user approval before proceeding to Phase 2.

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

**Deep research — parallel agents:**
- Agent A: Search codebase for similar patterns (`dl-explain --rank`, `dl-explain <component>`)
- Agent B: Read relevant external docs/references (API docs, schema files, config)
- Agent C: Check `FILE_CHANGES_WITH` edges for hidden coupling (`dl-explain --node` on affected files)

**Co-change coupling:** Always run `dl-explain --node <file>` on affected files to check which files historically change together. Files with `FILE_CHANGES_WITH` edges are likely coupled — include them in the plan.

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

T3 Gate: Present plan summary. Wait for approval.

After approval: T2 Inform — "Plan saved to `.devline/plans/{path}/plan.md`. Use `/dl-feature` to execute."

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
