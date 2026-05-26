## /dl-feature — Feature Navigation Hub

Invoked when `dl-feature` is called with no description, or explicitly as `/dl-feature resume`.

### Step 1: Detect mode and collect active features (T1 Silent)

Read `.devline/config.json` to get `mode`.

#### Project mode — scan local plans only

```bash
find .devline/plans -maxdepth 2 -name "plan.md" \
  | xargs grep -L "Status.*COMPLETED\|Status.*ABORTED" 2>/dev/null \
  | grep -v archive/
```

#### Orchestrator mode — scan root + all registered children

```bash
# Root active features (same command as above)
find .devline/plans -maxdepth 2 -name "plan.md" \
  | xargs grep -L "Status.*COMPLETED\|Status.*ABORTED" 2>/dev/null \
  | grep -v archive/

# Per child project
for child_path in $(python3 -c "
import json
cfg = json.load(open('.devline/config.json'))
for p in cfg.get('projects', []):
    print(p['path'])
" 2>/dev/null); do
  find "$child_path/.devline/plans" -maxdepth 2 -name "plan.md" 2>/dev/null \
    | xargs grep -L "Status.*COMPLETED\|Status.*ABORTED" 2>/dev/null \
    | grep -v archive/ \
    | sed "s|^|$child_path:|"
done
```

Build a list of active features: each entry has `{ plan_path, feature_name, location, phase_summary }`.

Extract `feature_name` from the `# Plan:` heading in each plan.md.
Extract `phase_summary` from the last recorded phase status line (e.g., "Phase 3, Slice 2/4 in progress").

### Step 2: Present active features list (T3 Gate)

#### No active features anywhere

| Condition | Action |
|-----------|--------|
| No active features found (any mode) | T2 Inform: "[Devline] No active features — starting new." → load `phase-0-prd.md` |

#### Active features exist — present navigation

Format the list grouped by location:

```
## Active Features

### Root
  [1] Payment integration — Phase 3, Slice 2/4 in progress
  [2] User onboarding — Phase 1, Domain analysis

### api (services/api)
  [3] Fix auth refresh — Phase 5, Review pending

### web (apps/web)
  [4] User profile page — Phase 2, Slices approved
```

Present as a `dl:choice` gate — one option per active feature plus always a "Start new feature" option:

```dl:choice
question: Which feature do you want to work on?
options:
  - label: "[1] <feature name> — <location>, <phase summary>"
    description: Resume this feature
  - label: "[N] Start a new feature"
    description: Describe a new feature to build at this level
```

Wait for selection.

### Step 3: Route selection

| Selection | Action |
|-----------|--------|
| Existing feature at current level | Resume — follow Step 4 |
| Existing feature at child project | T2 Inform: "[Devline] Resuming: <name> at <child-path>". Read that child's plan and follow Step 4. |
| Start a new feature | Load `phase-0-prd.md` for this level |
| DEFAULT | Re-present the list |

### Step 4: Resume selected feature

Read from the selected plan.md:
- Feature name, PRD, Domain Analysis
- All `slice-N-*.json` files → build status map
- Current phase (from phase status sections in plan.md)

**Resume Point Decision Table:**

| State found in plan.md | Action |
|------------------------|--------|
| Phase 6 complete | T2 Inform: "Feature already complete." → return to Step 2 list |
| Phase 5: PASS recorded | → resume at Phase 6 |
| Phase 4: PASS recorded | → resume at Phase 5 |
| Phase 3: all slices DONE/PASS | → resume at Phase 4 |
| Phase 3: some slices in progress | → read `steps[].done`, resume within Phase 3 |
| Phase 2: slices defined, none started | → resume at Phase 3 |
| Phase 0/1: no slices defined | → resume at Phase 0 |
| plan.md missing or empty | HALT: "Cannot resume — no plan found. Start fresh with /dl-feature." |
| DEFAULT | → resume at earliest incomplete phase |

CHECKPOINT: "[Devline] Resuming at: Phase <N> — <feature name>"

### Step 5: Show resume status

```
## Resuming: <Feature Name>
Location: <root | child-project-name>

| Slice | Status | Progress |
|-------|--------|----------|
| 1: <name> | ✅ done | — |
| 2: <name> | 🔄 in_progress | Step 2/5 done |
| 3: <name> | ⏳ pending | — |

Resuming at: Slice 2 (continuing from Step 3)
```

Then continue from the identified phase/slice.

### Edge Cases

| Case | Action |
|------|--------|
| Child project in list has no `.devline/plans/` | Skip it, T2 Warn: "[Devline] <child> has no plans — skipping" |
| All listed features are actually completed | → T2 Inform: "No active features" → load phase-0-prd.md |
| Child project path in config no longer exists | T2 Warn: "[Devline] <child-path> not found — skipping" |
| DEFAULT | Re-present list |
