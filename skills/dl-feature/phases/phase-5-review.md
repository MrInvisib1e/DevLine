## Phase 5: Final Review

Goal: holistic architecture-aware review of the complete feature.

### Step 1: Dispatch Final Review Agent

Combine:
- `agents/final-review.md` — role/contract
- Full `plan.md` (PRD + domain + all slice statuses + integration results)
- All files changed across all slices (from each slice's `files_changed`)
- `.devline/memory/` — project architecture context

Wait for Final Review Report.

### Step 2: Handle Result

**PASS:** Proceed to Phase 6. Record `## Phase 5 Status: COMPLETE` in `plan.md`.

**FAIL:**
- Read BLOCKING_ISSUES and Required Changes
- Determine which slices are affected
- Re-open affected slices: reset `status: "pending"`, create new slice JSON/MD for fix if needed
- Re-run Phase 3 for affected slices only
- Re-run Phase 5 after fixes
- If FAIL after >2 cycles: escalate to user — present all findings and ask for direction

Write final review result to `plan.md` under `## Final Review`.
