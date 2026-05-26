## Phase 0: PRD Interrogation

Goal: turn a feature description into a structured PRD that everyone agrees on before any code is planned.

<iron-law>
Load `skills/_shared.md` before proceeding. T1/T2/T3 tiers and SIF rules are defined there and assumed throughout this phase.
DO NOT proceed to Phase 1 until the user explicitly approves the PRD.
</iron-law>

### Mode Detection (T1 Silent)

| Condition | Mode |
|-----------|------|
| `.devline/config.json` exists AND has `stack.runtime` set | Existing project |
| `.devline/config.json` missing OR `stack.runtime` is null | Confirm with user: "This looks like a greenfield project — is that right?" Wait for answer before proceeding. |
| User says "from scratch", "new project", "build a..." with no existing code | Greenfield project |
| DEFAULT | Existing project |

— because an existing project with an incomplete config would be silently misclassified as Greenfield, sending the user through a much longer question flow.

---

### Existing Project — Full Mode (QUICK_MODE=false)

Ask these questions **ONE AT A TIME**. Wait for the answer before asking the next.

1. **Actor:**
   ```dl:choice
   question: Who is the primary actor?
   options:
     - label: Authenticated user
       description: A logged-in user acting on their own data
     - label: Admin
       description: A privileged user managing others' data or system config
     - label: Anonymous visitor
       description: An unauthenticated user with read-only or public access
     - label: Background job / system
       description: An automated process, not a human actor
   ```
2. **Goal:**
   ```dl:choice
   question: What does the actor want to accomplish? (pick closest, or select Other to type your own)
   options:
     - label: View / list a resource
       description: Read-only access to existing data
     - label: Create / submit a resource
       description: Add new data to the system
     - label: Edit / update a resource
       description: Modify existing data
     - label: Delete / remove a resource
       description: Remove data from the system
   ```
3. **Scope:**
   ```dl:choice
   question: What is explicitly IN scope for this feature? (select all that apply)
   multiple: true
   options:
     - label: CRUD on entity + API endpoint
       description: Standard create/read/update/delete operation with backend API
     - label: UI form + API endpoint
       description: A user-facing form that calls a backend endpoint
     - label: Background processing + status UI
       description: Async job with a polling or status-display component
     - label: Third-party integration (read-only)
       description: Fetching or displaying data from an external service
   ```
4. **Out of scope:**
   ```dl:choice
   question: What is explicitly OUT of scope? (select all that apply)
   multiple: true
   options:
     - label: Bulk operations
       description: Acting on many records at once
     - label: Admin tooling
       description: Backoffice or privileged management interfaces
     - label: Mobile / native app
       description: Native iOS or Android clients
     - label: Email / push notifications
       description: Outbound messaging triggered by events
   ```
5. **Success criteria:**
   ```dl:choice
   question: Which best describes the success criteria? (select all that apply, then we'll refine)
   multiple: true
   options:
     - label: Actor can perform action and sees result
       description: "[Actor] can [verb] [noun] and sees [confirmation/result]"
     - label: Entity appears / disappears in list or view
       description: "Created/deleted items are immediately visible in the relevant list"
     - label: Error message shown for invalid input
       description: Validation errors are surfaced clearly to the user
     - label: Change persists after page reload
       description: Data is durably stored, not just in-memory
   ```
6. **Edge cases:**
   ```dl:choice
   question: Which edge cases should be handled? (select all that apply)
   multiple: true
   options:
     - label: Empty state (no items yet)
       description: What the user sees before any data exists
     - label: Validation errors on form submit
       description: Required fields missing, format errors, etc.
     - label: Permission denied (unauthorized user)
       description: User tries to access or act on something they can't
     - label: None — straightforward CRUD
       description: No special edge cases beyond the happy path
   ```

After all answers, present the structured PRD (see PRD Template below).

### Existing Project — Quick Mode (QUICK_MODE=true)

Ask only:
1. **Actor:**
   ```dl:choice
   question: Who is the primary actor?
   options:
     - label: Authenticated user
       description: A logged-in user acting on their own data
     - label: Admin
       description: A privileged user managing others' data or system config
     - label: Anonymous visitor
       description: An unauthenticated user with read-only or public access
     - label: Background job / system
       description: An automated process, not a human actor
   ```
2. **Acceptance criteria:**
   ```dl:choice
   question: What are 2-3 key acceptance criteria? (select all that apply)
   multiple: true
   options:
     - label: Actor can perform the core action
       description: "[Actor] can [verb] [noun]"
     - label: Error shown for invalid input
       description: Validation or error states are handled
     - label: Change persists after reload
       description: Data is durably saved
   ```

Generate the PRD from the description + these 2 answers. Present for approval.

**Quick-mode inference rules (T2 Inform — label all inferred fields):**

| Field | Inference rule |
|-------|---------------|
| Goal | Derive from feature description + actor answer |
| Scope | Assume the minimal set of changes implied by the description |
| Out of scope | Assume: bulk operations, admin tooling, mobile, notifications, i18n |
| Edge cases | Assume: empty state, validation errors, permission denied |
| DEFAULT | State assumption explicitly in the PRD |

Print: "[Devline] Quick-mode PRD: inferred [Goal / Scope / Out of scope / Edge cases]. Review and correct if anything is wrong." — because the prior instruction gave no guidance on what to infer, producing inconsistent PRDs across sessions.

---

### Greenfield Project Mode

When building from scratch with no existing stack or architecture, the PRD needs to be more expansive.

Ask these questions **ONE AT A TIME**:

1. **Vision:** "What are you building? Describe it in 1-2 sentences."
2. **Users & Personas:** "Who will use this? Describe 1-3 user types and their primary goals."
3. **Core User Stories:** "What are the 3-5 most important things a user should be able to do?"
4. **Stack Selection:** "Do you have a preferred tech stack? (runtime, framework, database, hosting) — or should I recommend one?"
   - If user wants recommendation: propose 2-3 stack options with trade-offs using a `dl:choice` block. Wait for selection.
5. **Constraints (BEFORE architecture):** "Any important constraints? (auth, compliance, rate limits, data size, budget, team expertise)"
   — because a user may approve an architecture that violates constraints they haven't yet been asked about; constraints must come first.
6. **Architecture Blueprint:** "Based on the stack and constraints, here's the proposed architecture:" — present:
   - Application type (monolith / API+SPA / serverless / etc.)
   - Data model sketch (key entities and relationships)
   - API style (REST / GraphQL / RPC)
   - Deployment model (container / serverless / static + API)
   - Wait for approval.
7. **MVP Scope:** "What's in v1 vs what's deferred?" — present a MoSCoW table:
   - Must have (v1)
   - Should have (v1 if time)
   - Could have (v2)
   - Won't have (explicitly out)
   - Wait for approval.
8. **Success criteria:** "How will we know v1 is done? List 3-5 acceptance criteria."

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
**Approved:** [YYYY-MM-DD HH:MM — filled in at approval time]
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

**Approved:** [YYYY-MM-DD HH:MM — filled in at approval time]
```

---

### Scope Contradiction Check (T1 Silent — before presenting PRD)

Before presenting the PRD, verify: does any item in "Out of scope" contradict an item in "Scope"?

| Check | Example conflict | Action |
|-------|-----------------|--------|
| In-scope item requires out-of-scope item to work | "Edit user profile" in scope, "auth" out of scope | T2 Inform: "Possible scope conflict: [X requires Y]. Clarifying..." — resolve inline |
| Out-of-scope item is a dependency of a success criterion | "User sees list" criterion, but "list API" out of scope | T2 Inform: same pattern |
| No conflicts | — | Proceed silently |

---

### STOPPING GATE — PRD Approval

```dl:choice
question: Does this PRD look right?
options:
  - label: Yes, proceed
    description: PRD is approved — move to domain analysis
  - label: Change something
    description: I want to adjust part of the PRD before proceeding
default: Yes, proceed
```

**DO NOT proceed to Phase 1 until the user explicitly approves the PRD.**

If the user requests changes: revise the PRD and re-present it. Repeat until approved.

**On approval:** Fill in the `Approved:` timestamp in the PRD and write it to `plan.md`. — because on resume, there is no way to know if the PRD is still current without a timestamp.

### Orchestrator Child Proposal (only when ORCHESTRATOR_MODE=true)

After PRD approval, before proceeding to Phase 1:

**Step O-1: Read child project contexts (T1 Silent)**

Read `.devline/config.json` `projects` list. For each registered child:
1. Read `<child-path>/.devline/memory.md` if it exists
2. Read `<child-path>/.devline/config.json` for stack info
3. If child has no `.devline/`: T2 Warn — "[Devline] <child-name> has no .devline/ — skipping"

**Step O-2: Propose involvement (T2 Inform)**

For each child project, reason about whether the PRD's actor, goal, and scope are likely to touch that project. Build a proposal table:

```
| Project | Involved? | Reason |
|---------|-----------|--------|
| api     | Yes       | Feature requires a new endpoint for X |
| web     | Yes       | Feature requires UI changes for X |
| worker  | No        | Background job unrelated to this feature |
```

**Step O-3: Child involvement approval (T3 Gate)**

```dl:choice
question: These are the child projects I propose to involve in this feature. Adjust if needed.
options:
  - label: Looks right, proceed
    description: Use this project selection for the feature plan
  - label: Change selection
    description: I want to include or exclude specific projects
```

If "Change selection": ask "Which projects should be included or excluded?" (open text). Update the table and re-present.

**After approval:** Record the involved child projects in `plan.md` under `## Involved Projects`. Proceed to Phase 1.
