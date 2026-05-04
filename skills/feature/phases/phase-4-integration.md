# Phase 4: Integration Testing

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
CHECKPOINT: "[DevFlow] Contract manifest built: N interaction points"

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

CHECKPOINT: "[DevFlow] Integration tests: PASS"
