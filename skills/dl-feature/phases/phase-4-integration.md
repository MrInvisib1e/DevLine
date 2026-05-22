# Phase 4: Integration Testing

<iron-law>
Load `skills/_shared.md` before proceeding. T1/T2/T3 tiers assumed throughout.
</iron-law>

## Purpose

Validate that parallel slices work correctly together. Catch contract violations (interface mismatches) before final review.

## Step 1 — Build contract manifest (T1)

For each completed slice, extract:
- **Exports**: functions, types, components exported from the slice's files
- **Imports**: what the slice imports from other slices (not external packages)
- **Assumptions**: any documented assumptions about other slices' behavior

Build a cross-reference table:

```
| Slice A exports | Slice B imports | Match? |
|----------------|-----------------|--------|
| <function>      | <function>      | ✓ / ✗  |
```

T1 Silent — this is mechanical extraction.
CHECKPOINT: "[Devline] Contract manifest built: N interaction points"

## Step 2 — Static contract validation (T1)

Check:
1. Every import of cross-slice symbols matches an export
2. Function/type signatures are compatible (same name, compatible types if visible)
3. No circular slice dependencies

### Static Validation Table

| Finding | Severity | Action |
|---------|----------|--------|
| Import not exported | BLOCKING | → route to responsible slice for fix |
| Signature mismatch | BLOCKING | → route to responsible slice for fix |
| Circular dependency | HIGH | → T3 Gate, ask for resolution |
| All contracts satisfied | — | → proceed to Step 3 |
| DEFAULT | — | → proceed, flag for integration agent |

If blocking violations found: route back to the specific slice(s) responsible. Do NOT route to all slices.

```dl:choice
question: A circular dependency was detected between slices. How do you want to resolve it?
options:
  - label: Extract shared abstraction
    description: Move the shared code to a new module both slices can import
  - label: Merge the two slices
    description: Combine the circular slices into a single slice
  - label: Break the cycle manually
    description: I'll describe how to restructure the dependency
```

## Step 3 — Dispatch integration test agent

Dispatch integration agent with:
- Contract manifest from Step 1
- List of responsible_slices for any unresolved contract issues
- Access to all slice output files

The integration agent writes cross-slice integration tests and verifies they pass.

### Integration Result Table

| Agent Result | Violations? | Action |
|--------------|-------------|--------|
| PASS | none | → proceed to Phase 5 |
| PASS | minor notes | → T2 Inform notes, proceed to Phase 5 |
| FAIL | slice A issue | → route fix back to slice A agent only |
| FAIL | multiple slices | → route fixes to responsible slices |
| FAIL (3rd time) | any | → T3 Gate: show contract failures |
| DEFAULT | — | → T2 Inform, retry |

```dl:choice
question: Integration contract failed 3 times. How do you want to proceed?
options:
  - label: Route back to Phase 3
    description: Send failures to implementation agents to fix
  - label: Accept with known gaps
    description: Proceed with documented contract failures
  - label: Abort feature
    description: Stop and leave branch as-is for manual resolution
```

CHECKPOINT: "[Devline] Integration tests: PASS"

### If integration fails

| Failure type | Diagnosis | Recovery |
|-------------|-----------|----------|
| Merge conflict between slices | `git diff --name-only HEAD~1` to identify conflicting file | Resolve conflict in affected file, re-run integration test |
| Slice dependency missing | Check slice JSON `depends_on` fields | Ensure dependency slice is DONE before retrying |
| Type errors after merge | Run typecheck command from `quality_hooks` | Fix type errors in the merged output |
| Tests pass but behavior broken | Check integration test vs unit test coverage gap | Add integration test covering the broken path |
| DEFAULT | T2 Warn + T3 Gate if unresolved after 1 retry | |
