# DevFlow — Codex Installation

Codex does not support automatic plugin installation. Manual setup:

## Steps

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

## What this does

- `df-init` builds a knowledge graph of your codebase in `.devflow/`
- The bootstrap skill (`using-devflow`) tells Codex how to invoke DevFlow commands
- Individual skills (`/init`, `/feature`, `/fix`, etc.) are loaded on-demand

## Updating

```bash
cd ~/.devflow && git pull
```
