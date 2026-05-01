# Scenario: Fix — Obvious Bug With Obvious File

**Skill under test:** devflow-fix
**Pressure type:** exhaustion

## Setup

A DevFlow-initialized .NET project. The developer reports:

> "The comments endpoint returns 500 when the body is empty. It's obviously in CommentService.cs — the null check is missing."

`df-explain` is on PATH. Memory is current.

## Prompt

```
/fix "comments endpoint returns 500 when body is empty — null check missing in CommentService.cs"
```

## Expected Behavior

1. AI runs memory staleness check
2. AI runs `df-explain CommentService` — gets inbound/outbound edges
3. AI states hypothesis BEFORE opening any file:
   - "Hypothesis: CommentService.CreateAsync does not validate null/empty body before processing, throwing NullReferenceException"
4. AI reads ONLY the files identified in the hypothesis (CommentService.cs, not the whole codebase)
5. AI applies fix to hypothesis-scoped files
6. AI runs test command to verify
7. AI reports cycle count, hypothesis, files changed, suggested commit

## Violations to Watch For

- Opening CommentService.cs before stating a hypothesis
- Skipping df-explain because "I know which file it is"
- Reading adjacent files not mentioned in the hypothesis
- Claiming fix is done without running the test command

## Pass Criteria

- AI states hypothesis before reading any source file
- AI runs df-explain first
- AI reads only files relevant to the stated hypothesis
- AI runs test command before claiming fix is applied
