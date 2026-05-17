# Devline Bootstrap

Devline is active. Use `dl-*` skills for all development workflows.

## Iron Law

Before any Devline operation: verify `.devline/` exists in the current directory or git root.

If absent: HALT — "Run `/dl-init` first."

---

## Available Commands

| Command | Purpose |
|---------|---------|
| `/dl-init` | Initialize Devline + index codebase with codebase-memory-mcp |
| `/dl-feature` | Full feature lifecycle (PRD → slices → execution → review → merge) |
| `/dl-fix` | Hypothesis-driven bug fixing (max 3 cycles, behavior contract, TDD) |
| `/dl-review` | Convention-driven code review (0 gates, fully autonomous) |
| `/dl-plan` | Brainstorm → Research → Implementation plan |
| `/dl-sync` | Regenerate memory.md |
| `/dl-verify` | Pre-completion verification gate |
| `/dl-benchmark` | A/B test skills with falsifiable assertions |
| `/web-style` | Web component/page | Audit styling, accessibility, design system compliance |

---

## Skill Routing

Check for applicable skills BEFORE any response or action. Even 1% chance a skill applies = invoke it.

| Situation | Use |
|-----------|-----|
| Starting work in new repo | `/dl-init` |
| New feature or enhancement | `/dl-plan` then `/dl-feature` |
| Vague idea to flesh out | `/dl-plan --brainstorm` |
| Something is broken | `/dl-fix` |
| About to merge / code review | `/dl-review` |
| About to claim done | `/dl-verify` |
| "Fix this test" | `fix-test` skill |
| "Generate test for route" | `gen-test` skill |
| "Run and fix tests in loop" | `test-loop` skill |
| Implementation code (Svelte/SvelteKit) | `sveltekit-web-dev` skill |
| .NET backend code | `dotnet` skill |
| Architecture decision | `architecture` skill |
| Code review received | `receiving-review` skill |
| Writing a new skill | `writing-skills` skill + `tdd` skill |
| Styling, accessibility, WCAG, contrast, design tokens, responsive | `web-style` |

### Quick feature vs /dl-fix

| Signal | Use |
|--------|-----|
| Something is **broken** (regression, error, unexpected behavior) | `/dl-fix` |
| Something is **missing** (new behavior, enhancement) | `/dl-feature` or `/dl-feature quick` |
| DEFAULT (ambiguous) | Ask user: "Is something broken or are we adding something new?" |

---

## Auto-Skill Activation

Read `auto_skills` from `.devline/config.json`. For each rule, if the user's message matches the `trigger` regex, load the specified skill before responding.

```bash
python3 -c "
import json, re, sys
msg = sys.argv[1]
c = json.load(open('.devline/config.json'))
for r in c.get('auto_skills', []):
    if re.search(r['trigger'], msg, re.IGNORECASE):
        print(r['skill'])
" "$USER_MESSAGE" 2>/dev/null
```

Example config:
```json
"auto_skills": [
  { "trigger": "ovell|story|chapter|translation", "skill": "ovell-domain-canon" },
  { "trigger": "notification|event|realtime", "skill": "architecture" }
]
```

---

## Discipline Skills (always available)

| Skill | Invoke when |
|-------|------------|
| `tdd` | Implementing any feature or bugfix — write failing test first |
| `receiving-review` | Received code review feedback |
| `worktrees` | Need isolated workspace for feature work |
| `writing-skills` | Creating a new skill |

---

## Red Flags — Stop and Check Skills

| Thought | Reality |
|---------|---------|
| "Simple question, no skill needed" | Questions are tasks. Check for skills. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "I remember this skill" | Skills evolve. Always reload. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "This doesn't count as a task" | Action = task. Check for skills. |

---

## Coexistence

Devline handles: dl-init, dl-feature, dl-fix, dl-review, dl-plan, dl-sync, dl-verify, dl-benchmark

User custom skills (from config `auto_skills`): loaded dynamically per trigger

No overlap expected between Devline commands and custom skills.
