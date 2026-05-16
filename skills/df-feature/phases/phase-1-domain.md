## Phase 1: Domain Analysis

Goal: understand which codebase areas this feature will touch, and extract patterns for agents to follow.

### Step 1: Load Project Structure

Run:

```bash
df-explain
```

Read the output. Identify which modules, services, and controllers are relevant to the PRD. If `df-explain` fails: retry once; if still failing, proceed with degraded analysis and warn the user (error E13).

### Step 2: Identify Affected Modules

Based on the PRD and `df-explain` output, list:

- **Backend modules:** which services, entities, and controllers will be touched
- **Frontend modules:** which components, routes, and stores will be touched
- **Database:** any new tables or migrations needed
- **Dependencies:** any external services, APIs, or packages needed

### Step 3: Gather Code Patterns

Find a **reference feature** — an existing feature in the codebase that is structurally similar to what we're building.

Ask the user: "I'll use `[feature X]` as the reference for code patterns. Does that work, or is there a better reference?"

**Greenfield fallback (no similar feature):** Use `.devflow/memory/` architecture docs and `CONTRIBUTING.md` if present.

Read up to 5 key files from the reference feature:
- Entity/model
- Service/repository
- Controller/API handler
- Frontend component
- Test file

Extract patterns. They will be written to `plan.md` in Phase 2 under `## Pattern Library`. For now, hold them in session context.

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
