# Plan 4: Standalone Plugin Architecture

**Status:** Ready  
**Depends on:** All other plans (skills must be finalized before packaging)  
**Estimated tasks:** 6  
**Execute after:** Plans 6, 1, 2, 3, 5

## Context

DevFlow currently requires manual installation: clone to `~/.devflow`, add `bin/` to PATH, manually edit `~/.claude/CLAUDE.md`. It only works with Claude Code via manual skill registration. This plan makes DevFlow a standalone npm-publishable package with multi-platform support, mirroring the Superpowers plugin pattern. Net effect: single-command install on 5 platforms, bootstrap skill loaded on session start, individual skills loaded on-demand (60-70% token reduction vs. current always-in-context approach).

## Pre-flight

- [ ] All other plans complete (skills finalized)
- [ ] Node.js available: `node --version`
- [ ] `package.json` does NOT exist at repo root: `[[ ! -f package.json ]] && echo OK`
- [ ] Read Superpowers' `.opencode/plugins/superpowers.js` as reference implementation

## Tasks

### Task 4.1 — Create package.json and npm structure

**File(s):**
- Create: `package.json`
- Create: `bin/devflow` (main CLI entry point)

**What:**
Create the npm package manifest that enables global installation via npm.

`package.json`:
```json
{
  "name": "@devflow/skills",
  "version": "3.0.0",
  "description": "AI development workflow skills — makes AI behave like a senior engineer",
  "type": "module",
  "main": ".opencode/plugins/devflow.js",
  "bin": {
    "df-init":      "./bin/df-init",
    "df-sync":      "./bin/df-sync",
    "df-test":      "./bin/df-test",
    "df-workspace": "./bin/df-workspace",
    "df-explain":   "./bin/df-explain",
    "df-export":    "./bin/df-export",
    "df-resolve":   "./bin/df-resolve",
    "df-migrate":   "./bin/df-migrate"
  },
  "files": [
    "bin/",
    "skills/",
    "hooks/",
    ".claude-plugin/",
    ".cursor-plugin/",
    ".opencode/",
    "gemini-extension.json",
    "GEMINI.md",
    ".codex/"
  ],
  "keywords": ["ai", "developer-tools", "claude", "opencode", "skills"],
  "engines": {
    "node": ">=18.0.0"
  },
  "devflow": {
    "skills_dir": "./skills",
    "bootstrap_skill": "using-devflow"
  }
}
```

`bin/devflow` — main CLI entry for non-skill commands:
```bash
#!/usr/bin/env bash
# DevFlow CLI entry point
# Usage: devflow <command> [args]
case "${1:-help}" in
  init)      shift; exec "$(dirname "$0")/df-init" "$@" ;;
  sync)      shift; exec "$(dirname "$0")/df-sync" "$@" ;;
  explain)   shift; exec "$(dirname "$0")/df-explain" "$@" ;;
  migrate)   shift; exec "$(dirname "$0")/df-migrate" "$@" ;;
  help|*)
    echo "DevFlow v3"
    echo "Usage: devflow <command>"
    echo "  init     — Initialize DevFlow memory for a repo"
    echo "  sync     — Sync memory with code changes"
    echo "  explain  — Query the knowledge graph"
    echo "  migrate  — Migrate from JSON to SQLite graph store"
    echo ""
    echo "Or use individual commands: df-init, df-sync, df-explain, etc."
    ;;
esac
```

**Verify:**
```bash
[[ -f package.json ]] && echo exists
node -e "const p = require('./package.json'); console.log(p.name, p.version)"
# "@devflow/skills 3.0.0"
grep '"bin"' package.json
```

---

### Task 4.2 — Create bootstrap skill (using-devflow)

**File(s):**
- Create: `skills/using-devflow/SKILL.md`

**What:**
The only skill loaded at session start (~200-300 tokens). Tells the AI that DevFlow is active, how to use skills, and the single Iron Law.

```markdown
---
name: using-devflow
requires: []
triggers_on_complete: []
---

# DevFlow v3

<iron-law>
Before any DevFlow operation: verify `.devflow/` exists in the project root.
If absent: HALT. Print exactly: "DevFlow not initialized. Run /init first."
</iron-law>

DevFlow is active in this session.

## What DevFlow is

A skill library that makes AI behave like a senior engineer.
Your `.devflow/` directory contains a knowledge graph of this codebase.

## Available skills

| Skill | Command | When to use |
|-------|---------|-------------|
| init | `/init` | First-time setup on a new repo |
| feature | `/feature <desc>` | Implement a new feature (full lifecycle) |
| feature quick | `/feature quick <desc>` | Quick feature (no PRD phase) |
| fix | `/fix <desc>` | Debug and fix a bug |
| review | `/review` | Review staged/unstaged changes |
| plan | `/plan <desc>` | Generate implementation plan only |
| mem-sync | `/mem-sync` | Manually sync memory with code |
| verify | `/verify` | Verify work before claiming complete |

## How to use a skill

When the user invokes a skill command, load the corresponding `SKILL.md`:
- `/init` → load `skills/init/SKILL.md`
- `/feature` → load `skills/feature/SKILL.md`
- `/fix` → load `skills/fix/SKILL.md`
- `/review` → load `skills/review/SKILL.md`
- `/plan` → load `skills/plan/SKILL.md`
- `/mem-sync` → load `skills/mem-sync/SKILL.md`
- `/verify` → load `skills/verify/SKILL.md`

Load skills on-demand. Do NOT load all skills at once.

## Key context files

After `/init` is run on this repo, read these for context:
- `.devflow/active/memory.md` — top nodes by PageRank, architecture overview
- `df-explain --rank` — full ranked knowledge graph
- `df-explain <node-id>` — specific node's connections

## If Superpowers is also installed

DevFlow handles: init, feature, fix, review, plan, mem-sync, verify.
Superpowers handles: brainstorming, TDD, systematic debugging, writing plans.
No overlap. Use both freely.
```

**Verify:**
```bash
[[ -f skills/using-devflow/SKILL.md ]] && echo exists
wc -w skills/using-devflow/SKILL.md  # <250 words (≈300 tokens)
grep "<iron-law>" skills/using-devflow/SKILL.md
grep "Load skills on-demand" skills/using-devflow/SKILL.md
```

---

### Task 4.3 — Create OpenCode plugin

**File(s):**
- Create: `.opencode/plugins/devflow.js`

**What:**
OpenCode plugin that: (1) reads the bootstrap skill, (2) injects it into the first user message, (3) registers the skills directory, (4) adds `bin/` to PATH.

```javascript
// .opencode/plugins/devflow.js
import { readFileSync } from "fs"
import { join, dirname } from "path"
import { fileURLToPath } from "url"

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = join(__dirname, "../..")  // Development-Flow root

function getBootstrapContent() {
  const skillPath = join(ROOT, "skills/using-devflow/SKILL.md")
  let content
  try {
    content = readFileSync(skillPath, "utf8")
  } catch {
    return ""
  }
  // Strip YAML frontmatter
  content = content.replace(/^---[\s\S]*?---\n/, "")
  return content.trim()
}

export default {
  name: "devflow",

  config(config) {
    // Register skills directory for skill discovery
    config.skills = config.skills || []
    if (!config.skills.includes(join(ROOT, "skills"))) {
      config.skills.push(join(ROOT, "skills"))
    }

    // Add bin/ to PATH
    const binDir = join(ROOT, "bin")
    const currentPath = process.env.PATH || ""
    if (!currentPath.includes(binDir)) {
      process.env.PATH = `${binDir}:${currentPath}`
    }

    return config
  },

  "experimental.chat.messages.transform"(messages) {
    if (!messages || messages.length === 0) return messages

    const bootstrap = getBootstrapContent()
    if (!bootstrap) return messages

    const wrapped = `<DEVFLOW_ACTIVE>\n${bootstrap}\n</DEVFLOW_ACTIVE>`

    // Prepend to first user message
    const first = messages[0]
    if (first.role === "user") {
      const content = Array.isArray(first.content)
        ? [{ type: "text", text: wrapped }, ...first.content]
        : [{ type: "text", text: wrapped }, { type: "text", text: first.content }]
      return [{ ...first, content }, ...messages.slice(1)]
    }

    return messages
  }
}
```

**Verify:**
```bash
[[ -f .opencode/plugins/devflow.js ]] && echo exists
node -e "import('.opencode/plugins/devflow.js').then(m => console.log(m.default.name))"
# "devflow"
```

---

### Task 4.4 — Create Claude Code plugin manifest and hooks

**File(s):**
- Create: `.claude-plugin/plugin.json`
- Create: `hooks/hooks.json`
- Create: `hooks/session-start`
- Create: `hooks/run-hook.cmd`

**What:**
Claude Code SessionStart hook that injects the bootstrap skill content.

`.claude-plugin/plugin.json`:
```json
{
  "name": "devflow",
  "version": "3.0.0",
  "description": "DevFlow — AI development workflow skills",
  "hooks": "./hooks/hooks.json"
}
```

`hooks/hooks.json`:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "./hooks/run-hook.cmd session-start"
          }
        ]
      }
    ]
  }
}
```

`hooks/session-start` (bash script, outputs JSON for Claude Code):
```bash
#!/usr/bin/env bash
# Outputs bootstrap skill content as Claude Code additional context
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILL_FILE="${ROOT}/skills/using-devflow/SKILL.md"

if [[ ! -f "$SKILL_FILE" ]]; then
  echo '{"hookSpecificOutput": {"additionalContext": ""}}'
  exit 0
fi

# Strip YAML frontmatter
content=$(sed '/^---$/,/^---$/d' "$SKILL_FILE")

# Output JSON
content_escaped=$(printf '%s' "$content" | python3 -c "
import sys, json
print(json.dumps(sys.stdin.read()))
")

printf '{"hookSpecificOutput": {"additionalContext": %s}}' "$content_escaped"
```

`hooks/run-hook.cmd` (polyglot bash/cmd wrapper — same as Superpowers pattern):
```
@echo off & bash -c "exec bash %~f0 %*" & exit /b
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "${SCRIPT_DIR}/$1"
```

Make executables:
```bash
chmod +x hooks/session-start hooks/run-hook.cmd
```

**Verify:**
```bash
[[ -f .claude-plugin/plugin.json ]] && echo exists
[[ -f hooks/hooks.json ]] && echo exists
[[ -x hooks/session-start ]] && echo executable
# Test session-start output:
./hooks/session-start | python3 -c "import sys, json; d=json.load(sys.stdin); print('OK' if 'hookSpecificOutput' in d else 'FAIL')"
```

---

### Task 4.5 — Create Gemini CLI extension and Cursor plugin

**File(s):**
- Create: `gemini-extension.json`
- Create: `GEMINI.md`
- Create: `.cursor-plugin/plugin.json`
- Create: `hooks/hooks-cursor.json`
- Create: `.codex/INSTALL.md`

**What:**

`gemini-extension.json`:
```json
{
  "name": "devflow",
  "version": "3.0.0",
  "description": "DevFlow AI development workflow skills",
  "contextFileName": "GEMINI.md"
}
```

`GEMINI.md`:
```markdown
@./skills/using-devflow/SKILL.md

Tool mapping for Gemini CLI:
- TodoWrite → use built-in task tracking
- Bash → use shell tool
- Read/Write/Edit → use filesystem tools
- Task (subagent) → use gemini sub-agent features
```

`.cursor-plugin/plugin.json`:
```json
{
  "name": "devflow",
  "version": "3.0.0",
  "description": "DevFlow AI development workflow skills",
  "hooks": "../hooks/hooks-cursor.json"
}
```

`hooks/hooks-cursor.json`:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "./hooks/run-hook.cmd session-start"
          }
        ]
      }
    ]
  }
}
```

`.codex/INSTALL.md`:
```markdown
# DevFlow — Codex Installation

Codex does not support automatic plugin installation. Manual setup:

1. Clone DevFlow:
   ```bash
   git clone https://github.com/<user>/Development-Flow.git ~/.devflow
   ```

2. Add to PATH (in `~/.zshrc` or `~/.bashrc`):
   ```bash
   export PATH="$HOME/.devflow/bin:$PATH"
   ```

3. Add skills to your project's `AGENTS.md`:
   ```markdown
   @~/.devflow/skills/using-devflow/SKILL.md
   ```

4. Initialize a project:
   ```bash
   cd /your/project
   df-init
   ```
```

**Verify:**
```bash
[[ -f gemini-extension.json ]] && echo exists
[[ -f GEMINI.md ]] && echo exists
[[ -f .cursor-plugin/plugin.json ]] && echo exists
[[ -f .codex/INSTALL.md ]] && echo exists
```

---

### Task 4.6 — Update README with new installation instructions

**File(s):**
- Modify: `README.md` — Installation section

**What:**
Replace the current manual installation instructions with per-platform commands.

Replace the Installation section with:

```markdown
## Installation

### OpenCode (recommended)

Add to your `opencode.json`:
```json
{
  "plugin": ["devflow@git+https://github.com/<your-username>/Development-Flow.git"]
}
```

### Claude Code

```bash
/plugin install devflow@claude-plugins-official
```

Or from source:
```bash
git clone https://github.com/<user>/Development-Flow.git ~/.devflow
/plugin install ~/.devflow
```

### npm (global)

```bash
npm install -g @devflow/skills
```

Then add to your shell PATH: `df-init`, `df-sync`, etc. are now globally available.

### Cursor

```bash
/add-plugin devflow
```

### Gemini CLI

```bash
gemini extensions install https://github.com/<user>/Development-Flow
```

### Codex

See `.codex/INSTALL.md` for manual setup instructions.

---

## Quick Start

1. Install DevFlow using your platform's method above
2. In any git repository: start a conversation and type `/init`
3. DevFlow will scan your codebase and initialize memory
4. Use `/feature`, `/fix`, `/review`, etc. as needed
```

**Verify:**
```bash
grep "npm install\|plugin install\|opencode.json" README.md
grep "Quick Start\|/init" README.md
```

---

## Verification Gates

After all tasks complete:

- [ ] `package.json` exists with `"bin"` field listing all 8 df-* commands
- [ ] `skills/using-devflow/SKILL.md` exists, <300 tokens
- [ ] `.opencode/plugins/devflow.js` loads without errors: `node .opencode/plugins/devflow.js`... actually test via import
- [ ] `hooks/session-start` is executable and outputs valid JSON
- [ ] All 5 platform manifests exist:
  ```bash
  ls .claude-plugin/plugin.json .cursor-plugin/plugin.json \
     gemini-extension.json GEMINI.md .codex/INSTALL.md
  ```
- [ ] Bootstrap skill contains Iron Law and skill dispatch table
- [ ] Bootstrap skill does NOT contain all 7 skill contents (skills loaded on-demand)
- [ ] README installation section covers all 5 platforms

## Rollback

```bash
rm -f package.json bin/devflow
rm -rf skills/using-devflow/
rm -rf .opencode/ .claude-plugin/ .cursor-plugin/ .codex/
rm -f gemini-extension.json GEMINI.md
rm -f hooks/session-start hooks/hooks.json hooks/hooks-cursor.json hooks/run-hook.cmd
git checkout HEAD -- README.md
```
