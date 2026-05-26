## Phase 1: Domain Analysis

Goal: understand which codebase areas this feature will touch, and extract patterns for agents to follow.

<iron-law>
Load `skills/_shared.md` before proceeding. T1/T2/T3 tiers assumed throughout.
</iron-law>

### Step 1: Load Project Structure

Run:

```bash
dl-explain
```

| dl-explain result | Action |
|-------------------|--------|
| Success | Read output, proceed to Step 2 |
| Failure (exit non-zero) | Retry once |
| Failure on retry | T2 Warn: "[Devline] dl-explain failed — proceeding with degraded analysis (E13)." Continue with manual file inspection. |
| dl-explain not installed | T2 Warn: "[Devline] dl-explain not found — proceeding with manual analysis." |
| DEFAULT | Proceed with manual analysis |

Read the output. Identify which modules, services, and controllers are relevant to the PRD.

### Step 2: Identify Affected Modules

Based on the PRD and `dl-explain` output, list:

- **Backend modules:** which services, entities, and controllers will be touched
- **Frontend modules:** which components, routes, and stores will be touched
- **Database:** any new tables or migrations needed
- **Dependencies:** any external services, APIs, or packages needed

CHECKPOINT: "[Devline] Domain Step 2 done: affected modules identified"

#### Orchestrator Mode — Per-Child Domain Analysis (only when ORCHESTRATOR_MODE=true)

When in orchestrator mode, perform Step 2 for each involved child project separately:

| Child Project | Backend modules | Frontend modules | DB changes | Key risks |
|---------------|----------------|-----------------|------------|-----------|
| <child-name>  | <list>          | <list>           | yes/no     | <list>    |

For each involved child:
- Read `<child-path>/.devline/memory.md` for architecture context
- Identify only the modules within that child that the PRD touches
- Note any inter-child dependencies (e.g., "api must expose endpoint before web can implement UI")

The root `plan.md` will contain one `## Domain Analysis — <child-name>` section per involved child.

CHECKPOINT: "[Devline] Orchestrator domain analysis done: N child projects analyzed"

### Step 3: Gather Code Patterns

Find a **reference feature** — an existing feature in the codebase that is structurally similar to what we're building.

Present this gate to the user:

```dl:choice
question: I'll use `[feature X]` as the reference for code patterns. Does that work?
options:
  - label: Yes, use that reference
    description: Proceed with the identified reference feature
  - label: Use a different reference
    description: I'll name a better reference feature to use
default: Yes, use that reference
```

**Greenfield fallback (no similar feature):** Use `.devline/memory/` architecture docs and `CONTRIBUTING.md` if present.

<scope>READ: up to 5 files from the reference feature only. DO NOT: read entire directories, open unrelated files, or load more than 5 files total.</scope>

Read up to 5 key files from the reference feature:
- Entity/model
- Service/repository
- Controller/API handler
- Frontend component
- Test file

Extract patterns. They will be written to `plan.md` in Phase 2 under `## Pattern Library`. For now, hold them in session context.

CHECKPOINT: "[Devline] Domain Step 3 done: reference feature patterns extracted"

````markdown
## Pattern Library

### Entity Pattern (from Reference/Entity.cs)
```csharp
[paste real code snippet]
```

### Service Pattern (from Reference/Service.cs)
```csharp
[paste real code snippet]
```

### Controller Pattern (from Reference/Controller.cs)
```csharp
[paste real code snippet]
```

### Frontend Pattern (from reference/Component.svelte)
```svelte
[paste real code snippet]
```

### Test Pattern (from tests/reference.spec.ts)
```typescript
[paste real code snippet]
```
````

### Step 4: Capture Domain Analysis (Written to plan.md in Phase 2)

Assemble this section. It will be written to `plan.md` when the plan folder is created in Phase 2.

```markdown
## Domain Analysis

**Affected backend modules:** [list]
**Affected frontend modules:** [list]
**Database changes needed:** [yes/no — describe what]
**Reference feature:** [name + path]
**External dependencies:** [list or "none"]
**Key risks:** [list or "none"]
```

CHECKPOINT: "[Devline] Domain Step 4 done: domain analysis assembled, ready for Phase 2"
