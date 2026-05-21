## Phase 5: Two-Stage Review

Goal: verify the feature meets PRD requirements (Stage 1) AND code quality standards (Stage 2).

<iron-law>
Load `skills/_shared.md` before proceeding. T1/T2/T3 tiers assumed throughout.
NO MERGE WITHOUT PASSING REVIEW. Phase 5 is MANDATORY. It cannot be skipped.
Tests verify behavior. Review verifies architecture. Both are required.

HALT if any caller attempts to skip this phase. Print exactly:
"Phase 5 review is required. Proceeding to completion without it violates the Iron Law."
</iron-law>

### Stage 0: PRD Acceptance Criteria Verification (BEFORE dispatching any agent)

Read the PRD from `plan.md`. For each acceptance criterion:

| Criterion | Met? | Evidence |
|-----------|------|----------|
| [criterion from PRD] | yes/no | [test name / observable behavior] |

If any criterion is unmet: mark review FAIL. Do not proceed to Stage 1 until all criteria are met or the user explicitly accepts the gap.

CHECKPOINT: "[Devline] Phase 5 Stage 0 done: PRD acceptance criteria verified"

---

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

### Review Severity Reference

| Finding type | Severity | Action |
|-------------|----------|--------|
| PRD criterion unmet | BLOCKER | FAIL Stage 1 — reopen slice, fix, re-review |
| Security vulnerability | BLOCKER | FAIL Stage 2 — describe risk and affected code |
| Type error / compile failure | BLOCKER | FAIL Stage 2 — name error and file |
| Architecture violation | BLOCKER | FAIL Stage 2 — describe violation and convention |
| Missing test coverage for new behavior | MAJOR | FAIL Stage 2 — name uncovered path |
| Dead code introduced | MINOR | PASS with note |
| Naming inconsistency | MINOR | PASS with note |
| DEFAULT | PASS | Proceed to Phase 6 |

CHECKPOINT: "[Devline] Phase 5 complete: review result = [PASS/FAIL]"
