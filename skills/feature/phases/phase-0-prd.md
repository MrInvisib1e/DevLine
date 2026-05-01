## Phase 0: PRD Interrogation

Goal: turn a feature description into a structured PRD that everyone agrees on before any code is planned.

### Full Mode (QUICK_MODE=false)

Ask these questions **ONE AT A TIME**. Wait for the answer before asking the next.

1. **Actor:** "Who is the primary actor? (e.g., authenticated user, admin, anonymous visitor)"
2. **Goal:** "What does the actor want to accomplish? (one sentence)"
3. **Scope:** "What is explicitly IN scope for this feature?"
4. **Out of scope:** "What is explicitly OUT of scope? (prevents scope creep)"
5. **Success criteria:** "How will we know this feature is done? List 2-4 acceptance criteria."
6. **Edge cases:** "Are there any important edge cases or error states to handle?"

After all answers, present the structured PRD:

```
## PRD: <Feature Name>

**Actor:** <actor>
**Goal:** <goal>
**Scope:** <scope>
**Out of scope:** <out of scope>
**Success criteria:**
- <criterion 1>
- <criterion 2>
...
**Edge cases:** <edge cases>
```

### Quick Mode (QUICK_MODE=true)

Ask only:
1. "Who is the primary actor?"
2. "What are 2-3 key acceptance criteria?"

Generate the PRD from the description + these 2 answers. Present for approval.

### STOPPING GATE — PRD Approval

> **"Does this PRD look right? (yes to proceed, or tell me what to change)"**

**DO NOT proceed to Phase 1 until the user explicitly approves the PRD.**

If the user requests changes: revise the PRD and re-present it. Repeat until approved.
