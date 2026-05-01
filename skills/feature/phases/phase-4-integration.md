## Phase 4: Integration Testing

Goal: verify all slices work together as a complete feature.

Run AFTER all batches complete (even if some slices are stuck — test what's there).

**Quick mode skip:** If feature has only ONE slice: skip Phase 4 (single slice has no cross-slice interactions to test). Record `## Phase 4 Status: SKIPPED` in `plan.md`.

### Step 1: Dispatch Integration Test Agent

Combine:
- `agents/integration-test.md` — role/contract
- All completed slice MDs (from `plan.md` slice list — skip stuck slices)
- Full `plan.md`
- Domain context (test patterns)

Wait for Integration Test Report.

### Step 2: Handle Result

**DONE:** Proceed to Phase 5. Record `## Phase 4 Status: COMPLETE` in `plan.md`.

**DONE_WITH_CONCERNS:** Note concerns. Proceed to Phase 5 but flag concerns in `plan.md`. Record `## Phase 4 Status: COMPLETE_WITH_CONCERNS`.

**BLOCKED or failures:** Report to user. Ask: "Integration tests failing — see report. Fix and re-run integration tests, or proceed to final review anyway?"

Write integration test results to `plan.md` under `## Integration Test Results`.
