# Devline — Codex Installation

Codex does not support automatic plugin installation. Manual setup:

## Steps

1. Clone Devline:
   ```bash
   git clone https://github.com/MrInvisib1e/devline.git ~/.devline
   ```

2. Add to PATH (in `~/.zshrc` or `~/.bashrc`):
   ```bash
   export PATH="$HOME/.devline/bin:$PATH"
   ```

3. Add skills to your project's `AGENTS.md`:
   ```markdown
   @~/.devline/skills/using-devline/SKILL.md
   ```

4. Initialize a project:
   ```bash
   cd /your/project
   dl-init
   ```

## What this does

- `dl-init` builds a knowledge graph of your codebase in `.devline/`
- The bootstrap skill (`using-devline`) tells Codex how to invoke Devline commands
- Individual skills (`/init`, `/feature`, `/fix`, etc.) are loaded on-demand

## Updating

```bash
cd ~/.devline && git pull
```
