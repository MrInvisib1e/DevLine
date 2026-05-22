# Devline Interaction Protocol

Skills use `dl:choice` blocks to declare T3 Gates and structured questions. The AI follows this protocol to render them correctly for the current platform.

## Detection

At runtime, check whether the `AskUserQuestion` tool is available.

- **AskUserQuestion available** → use AskUserQuestion tool (renders native UI picker with automatic "Other" free-text fallback)
- **AskUserQuestion not available** → render plain text `[A]…[Z]` format

## dl:choice Block Syntax

Skill authors declare gates using fenced blocks:

~~~
```dl:choice
question: <question text shown to user>
multiple: <true | false>   # optional — default false (single-select)
options:
  - label: <short label>
    description: <one-line explanation>
  - label: <short label>
    description: <one-line explanation>
default: <label of recommended option, optional>
```
~~~

Rules:
- `question` is required
- At least 2 `options` are required
- Each option needs a `label` (1-5 words) and a `description` (one sentence)
- `default` is optional; if set, mark that option as recommended
- `multiple: true` allows the user to select more than one option (use for "select all that apply" questions)
- `multiple: false` (default) is single-select — use for mutually exclusive choices
- Options are A, B, C… in order (up to 26)

## Rendering Rules

### When AskUserQuestion is available

Call `AskUserQuestion` with:
- `question`: the `question` field
- `options`: each option as `{ label, description }`
- If `default` is set, append `" (Recommended)"` to that option's label
- `multiSelect`: `true` if `multiple: true`, otherwise `false`

The tool automatically appends an "Other" option so the user can always type a custom answer — skill authors do NOT need to add a manual free-text fallback option.

Wait for the returned selection, then proceed.

### When AskUserQuestion is not available

Render as:

```
[Devline] <question>

  [A] <label> — <description>
  [B] <label> — <description>
  [C] <label> — <description>      ← (Recommended) if default
  [Other] Type your own answer

What's your choice?
```

Wait for user to type A, B, C… (or the label text), then proceed.

## Implementation Notes

- Detection is done once per T3 gate encounter, not at skill load time
- The AI always waits for user input before proceeding past a T3 gate — no defaults are applied automatically
- If the user types something that doesn't match any option, accept it as a custom "Other" answer and proceed
- Yes/No approval gates (e.g., "Does this PRD look right?") SHOULD use `dl:choice` with "Yes, proceed" and "Change something" options — do not use plain text for these gates
- Use `multiple: true` for questions where multiple answers are valid (e.g., "What is out of scope?", "Which edge cases apply?")
