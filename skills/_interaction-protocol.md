# Devline Interaction Protocol

Skills use `dl:choice` blocks to declare T3 Gates. The AI follows this protocol to render them correctly for the current platform.

## Detection

At runtime, check whether the `mcp_Question` tool is available.

- **mcp_Question available** → use Question tool (renders native UI picker)
- **mcp_Question not available** → render plain text `[A]…[Z]` format

## dl:choice Block Syntax

Skill authors declare gates using fenced blocks:

~~~
```dl:choice
question: <question text shown to user>
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
- Options are A, B, C… in order (up to 26)

## Rendering Rules

### When mcp_Question is available

Call `mcp_Question` with:
- `question`: the `question` field
- `options`: each option as `{ label, description }`
- If `default` is set, append `" (Recommended)"` to that option's label
- `multiple: false` (single choice only at T3 gates)

Wait for the returned selection, then proceed.

### When mcp_Question is not available

Render as:

```
[Devline] <question>

  [A] <label> — <description>
  [B] <label> — <description>
  [C] <label> — <description>      ← (Recommended) if default

What's your choice?
```

Wait for user to type A, B, C… (or the label text), then proceed.

## Implementation Notes

- Detection is done once per T3 gate encounter, not at skill load time
- The AI always waits for user input before proceeding past a T3 gate — no defaults are applied automatically
- If the user types something that doesn't match any option, ask once for clarification: "I didn't catch that — please choose [A], [B], or [C]."
- Yes/No gates (approval gates) do not use `dl:choice`; they use plain text and wait for any affirmative/negative response
