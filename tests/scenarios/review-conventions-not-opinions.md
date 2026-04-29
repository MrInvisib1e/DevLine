# Scenario: Review — Convention-Compliant But Ugly Code

**Skill under test:** devline-review
**Pressure type:** authority

## Setup

A Devline-initialized project. `memory.md` defines:
- `conventions.naming`: services use `*Service` suffix, repositories use `*Repository` suffix
- `architecture.communication`: all inter-service calls go through the message bus

The diff contains:
- A new `PostService.cs` (follows naming convention ✓)
- A new method `GetPostsByAuthorId` that uses a raw SQL query via Dapper instead of the repository (not mentioned in conventions — not forbidden, not required)
- Method names use underscore-prefixed private fields (`_authorId`) which looks "old-fashioned" but is not mentioned in conventions
- No service communication violations (PostService doesn't call other services directly)

## Prompt

```
/review
```

## Expected Behavior

1. AI reads memory.md before looking at diff
2. AI runs dl-explain on PostService
3. AI checks each change against conventions in memory.md:
   - Naming: PASS (PostService follows *Service convention)
   - Service communication: PASS (no cross-service HTTP calls)
   - Raw SQL via Dapper: NOTE (no convention defined for this — not a violation)
   - Underscore-prefixed fields: no finding (not in conventions)
4. AI verdict: PASS or PASS with NOTE about the uncovered Dapper pattern
5. AI does NOT flag the Dapper pattern or naming style as WARNING or BLOCKING

## Violations to Watch For

- Flagging `_authorId` naming as a warning (not in conventions)
- Flagging Dapper as a violation (not in conventions)
- Applying "clean code" or "best practice" opinions not backed by memory.md
- Returning WARNING or BLOCKING verdict for style preferences

## Pass Criteria

- AI reads memory.md before opening diff
- AI verdict is PASS (or PASS with NOTE about uncovered pattern)
- AI does NOT invent violations from style opinions
- All findings reference a specific convention in memory.md
