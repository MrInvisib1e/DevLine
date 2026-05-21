## Phase 0: PRD Interrogation

Goal: turn a feature description into a structured PRD that everyone agrees on before any code is planned.

### Mode Detection (T1 Silent)

| Condition | Mode |
|-----------|------|
| `.devline/config.json` exists AND has `stack.runtime` set | Existing project |
| `.devline/config.json` missing OR `stack.runtime` is null | Greenfield project |
| User says "from scratch", "new project", "build a..." with no existing code | Greenfield project |
| DEFAULT | Existing project |

---

### Existing Project — Full Mode (QUICK_MODE=false)

Ask these questions **ONE AT A TIME**. Wait for the answer before asking the next.

1. **Actor:** "Who is the primary actor? (e.g., authenticated user, admin, anonymous visitor)"
   > Common variants: `authenticated user` · `admin` · `anonymous visitor` · `background job / system`
2. **Goal:** "What does the actor want to accomplish? (one sentence)"
   > Common variants: `view/list [resource]` · `create/submit [resource]` · `edit/update [resource]` · `delete/remove [resource]` · `receive notification about [event]`
3. **Scope:** "What is explicitly IN scope for this feature?"
   > Common variants: `[CRUD operation] on [entity]` · `UI form + API endpoint` · `background processing + status UI` · `third-party integration (read-only)`
4. **Out of scope:** "What is explicitly OUT of scope? (prevents scope creep)"
   > Common variants: `bulk operations` · `admin tooling` · `mobile/native app` · `email/push notifications` · `analytics/reporting` · `i18n/localization`
5. **Success criteria:** "How will we know this feature is done? List 2-4 acceptance criteria."
   > Common variants: `[Actor] can [verb] [noun] and sees [result]` · `[Entity] appears/disappears in [list/view]` · `Error message shown when [invalid input]` · `[Action] persists after page reload`
6. **Edge cases:** "Are there any important edge cases or error states to handle?"
   > Common variants: `empty state (no items yet)` · `validation errors on form submit` · `concurrent edits / race conditions` · `permission denied (unauthorized user)` · `network failure / timeout` · `none — straightforward CRUD`

After all answers, present the structured PRD (see PRD Template below).

### Existing Project — Quick Mode (QUICK_MODE=true)

Ask only:
1. "Who is the primary actor?"
   > Common variants: `authenticated user` · `admin` · `anonymous visitor` · `background job / system`
2. "What are 2-3 key acceptance criteria?"
   > Common variants: `[Actor] can [verb] [noun]` · `Error shown for invalid input` · `Change persists after reload`

Generate the PRD from the description + these 2 answers. Present for approval.

---

### Greenfield Project Mode

When building from scratch with no existing stack or architecture, the PRD needs to be more expansive.

Ask these questions **ONE AT A TIME**:

1. **Vision:** "What are you building? Describe it in 1-2 sentences."
2. **Users & Personas:** "Who will use this? Describe 1-3 user types and their primary goals."
3. **Core User Stories:** "What are the 3-5 most important things a user should be able to do?"
4. **Stack Selection:** "Do you have a preferred tech stack? (runtime, framework, database, hosting) — or should I recommend one?"
   - If user wants recommendation: propose 2-3 stack options with trade-offs using a `dl:choice` block. Wait for selection.
5. **Architecture Blueprint:** "Based on the stack, here's the proposed architecture:" — present:
   - Application type (monolith / API+SPA / serverless / etc.)
   - Data model sketch (key entities and relationships)
   - API style (REST / GraphQL / RPC)
   - Deployment model (container / serverless / static + API)
   - Wait for approval.
6. **MVP Scope:** "What's in v1 vs what's deferred?" — present a MoSCoW table:
   - Must have (v1)
   - Should have (v1 if time)
   - Could have (v2)
   - Won't have (explicitly out)
   - Wait for approval.
7. **Success criteria:** "How will we know v1 is done? List 3-5 acceptance criteria."
8. **Edge cases:** "Any important constraints? (auth, rate limits, data size, compliance)"

After all answers, present the Greenfield PRD (see Greenfield PRD Template below).

---

### PRD Template (Existing Project)

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

### Greenfield PRD Template

```
## PRD: <Project Name>

### Vision
<1-2 sentence description>

### Users & Personas
| Persona | Role | Primary Goal |
|---------|------|-------------|
| <persona 1> | <role> | <goal> |
| <persona 2> | <role> | <goal> |

### Core User Stories
1. As a <persona>, I want to <action> so that <benefit>
2. ...

### Stack
| Layer | Choice | Rationale |
|-------|--------|-----------|
| Runtime | <runtime> | <why> |
| Framework | <framework> | <why> |
| Database | <database> | <why> |
| Hosting | <hosting> | <why> |

### Architecture
- **Type:** <monolith / API+SPA / etc.>
- **Data model:** <key entities and relationships>
- **API style:** <REST / GraphQL / etc.>
- **Deployment:** <container / serverless / etc.>

### MVP Scope (MoSCoW)
| Priority | Feature |
|----------|---------|
| Must | <feature 1> |
| Must | <feature 2> |
| Should | <feature 3> |
| Could | <feature 4> |
| Won't | <feature 5> |

### Success Criteria
- <criterion 1>
- <criterion 2>
- <criterion 3>

### Constraints & Edge Cases
<constraints>
```

---

### STOPPING GATE — PRD Approval

> **"Does this PRD look right? (yes to proceed, or tell me what to change)"**

**DO NOT proceed to Phase 1 until the user explicitly approves the PRD.**

If the user requests changes: revise the PRD and re-present it. Repeat until approved.
