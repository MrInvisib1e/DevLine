---
name: devline-benchmark
description: A/B test a Devline skill against falsifiable assertions to measure effectiveness
requires: []
triggers_on_complete: []
---

# dl-benchmark

A/B test any Devline skill against falsifiable assertions to measure its effectiveness.

---

## When to Use

- You suspect a skill is not enforcing its rules consistently
- You've modified a skill and want to verify it still works
- You want to compare two skill variants (e.g., before/after a change)
- You want evidence for why a skill exists (or doesn't deserve to)

---

## Workflow

```
Step 1: Define assertion(s)
Step 2: Record a scenario (or pick from .devline/benchmark/scenarios/)
Step 3: Run control (without skill) — capture result
Step 4: Run treatment (with skill) — capture result
Step 5: Grade both runs against assertions
Step 6: Print verdict
```

---

## Step 1 — Define Assertions

Each assertion is a falsifiable YES/NO claim about what the agent should or should not do.

Format:
```json
{
  "id": "a1",
  "description": "Agent writes failing test before implementation code",
  "pass_if": "test file created before source file in commit order",
  "fail_if": "source file modified without corresponding test change"
}
```

Assertions go in: `.devline/benchmark/<benchmark-name>/assertions.json`

---

## Step 2 — Define Scenario

A scenario is a deterministic prompt + context that can be replayed identically.

Format: `.devline/benchmark/<benchmark-name>/scenario.md`

```markdown
## Scenario: <name>

### Context
<Minimal codebase description or pointer to fixture>

### Task
<Exact prompt the agent receives>

### Expected behavior
<What a disciplined agent should do, step by step>
```

Scenarios are replayable. Keep them minimal — don't describe half the codebase.

---

## Step 3 — Run Control

Run the scenario WITHOUT loading the target skill.

```bash
dl-benchmark run --scenario <name> --mode control
```

Capture:
- Files created/modified (from git diff)
- Sequence of actions (from agent log)
- Test commands run (yes/no, before/after code)
- Any rationalization phrases detected

---

## Step 4 — Run Treatment

Run the same scenario WITH the target skill loaded.

```bash
dl-benchmark run --scenario <name> --mode treatment --skill <skill-name>
```

Same capture as control.

---

## Step 5 — Grade

For each assertion, evaluate control and treatment results:

| Assertion | Control | Treatment |
|-----------|---------|-----------|
| a1: tests before code | FAIL | PASS |
| a2: scope fence respected | PASS | PASS |

---

## Step 6 — Verdict

Print:

```
BENCHMARK: <benchmark-name>
Assertions: <N> total, <M> tested
Control:   <X>/<N> pass
Treatment: <Y>/<N> pass
Delta:     +<Y-X> assertions
Verdict:   <IMPROVEMENT | NO_CHANGE | REGRESSION>
```

Save to: `.devline/benchmark/<benchmark-name>/results/<timestamp>.json`

---

## Running dl-benchmark

```bash
# Run a full benchmark
dl-benchmark run --scenario tdd-enforcement --skill tdd

# List all saved benchmarks
dl-benchmark list

# Show last result for a benchmark
dl-benchmark show tdd-enforcement

# Re-run last benchmark with updated skill
dl-benchmark rerun tdd-enforcement
```

---

## Included Scenarios

Pre-written scenarios in `.devline/benchmark/scenarios/`:

| Scenario | Tests |
|----------|-------|
| `tdd-pressure` | Agent writes code before tests under time pressure |
| `scope-creep` | Agent asked to "also fix X" while fixing Y |
| `hypothesis-skip` | Agent jumps to fix without stating hypothesis |
| `review-opinions` | Agent gives subjective review findings without convention backing |

---

## Current Status

`dl-benchmark` is a **stub** in v4.0. The `dl-benchmark` CLI script exists and accepts the commands above, but scenario replay is manual — the grading step requires the human to assess the agent log.

Automated replay (isolate agent, inject scenario, capture output programmatically) is planned for v4.1.

---

## You Will Be Tempted To

| Temptation | Reality |
|------------|---------|
| Skip assertions and just "feel" if it works | Feelings aren't evidence. Define assertions first. |
| Write one assertion that tests everything | One assertion = one failure mode. Be specific. |
| Write a scenario that's too complex | Complex scenarios have too many variables. Keep them minimal. |
| Skip the control run | Without a control, you don't know if the skill caused the improvement. |

## Red Flags — STOP

- Running benchmark without a baseline (control run first)
- Assertions that can't fail (unfalsifiable)
- "Close enough" on grading — use the rubric
- Skipping isolation (other skills/rules active during benchmark)
- Comparing runs with different context sizes

**Stop. Re-read the benchmark protocol. Follow it.**
