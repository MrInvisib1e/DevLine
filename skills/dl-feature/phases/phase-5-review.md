## Phase 5: Two-Stage Review

Goal: verify the feature meets PRD requirements (Stage 1) AND code quality standards (Stage 2).

### Stage 1: Spec Compliance Review

Dispatch spec compliance reviewer:

Combine:
- `agents/spec-reviewer.md` — role/contract
- Full `plan.md` (PRD + domain + all slice statuses)
- All files changed across all slices
- Full test results from Phase 4

Wait for Spec Compliance Report.

#### Handle Stage 1 Result

| Result | Action |
|--------|--------|
| PASS | Proceed to Stage 2 |
| FAIL | Read BLOCKING_ISSUES → re-open affected slices → re-run Phase 3 for affected slices → re-run Stage 1 |
| FAIL after >2 cycles | Escalate to user — present all findings, ask for direction |
| DEFAULT | Proceed to Stage 2 |

CHECKPOINT: "[Devline] Stage 1 (spec compliance): PASS"

### Stage 2: Code Quality Review

Dispatch final review agent:

Combine:
- `agents/final-review.md` — role/contract
- Full `plan.md` (PRD + domain + all slice statuses + integration results)
- All files changed across all slices
- `.devline/memory/` — project architecture context

Wait for Final Review Report.

#### Handle Stage 2 Result

| Result | Action |
|--------|--------|
| PASS | Proceed to Phase 6. Record `## Phase 5 Status: COMPLETE` in `plan.md` |
| FAIL | Read BLOCKING_ISSUES → determine affected slices → re-open → re-run Phase 3 → re-run Stage 2 |
| FAIL after >2 cycles | Escalate to user — present all findings, ask for direction |
| DEFAULT | Proceed to Phase 6 |

CHECKPOINT: "[Devline] Stage 2 (code quality): PASS"

Write both review results to `plan.md` under `## Final Review`.
