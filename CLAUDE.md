# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a modular zsh configuration system for macOS. The main `zshrc` file acts as a minimal loader that sources all `.zsh` files from the `~/.zsh/` directory.

## Deployment

```bash
./deploy.sh           # Interactive deployment with diff preview and backups
./deploy.sh --force   # Skip confirmations (still creates backups)
```

The deploy script:
1. Checks for additions in `~/` not present in local (warns if found)
2. Shows diffs between local and remote files
3. Creates timestamped backups in `~/.zsh-backup/`
4. Copies `zshrc` to `~/.zshrc` and `.zsh/*.zsh` to `~/.zsh/`

After deployment: `source ~/.zshrc`

## Architecture

```
zshrc                    # Main loader - sources all .zsh files alphabetically
.zsh/
  docker-tools.zsh       # Docker/Compose aliases (dkps, dc, dcu, etc.)
  extras.zsh             # PATH exports, NVM, FZF config, misc helpers
  git-tools.zsh          # Git/worktree power-user commands (gwt-*, gbr-*, etc.)
  hunt.zsh               # Unified search command using fd/rg/fzf
```

## Key Commands Provided

- `ghelp` / `ghelp workflows` - Git/worktree command reference
- `dkhelp` - Docker command reference
- `hunt -h` - Search command help

## Worktree Layout Convention

Git worktree commands (`gwt-*`) expect repos to use a bare repository layout with `.bare/` at the repo root. Branch worktrees are created as sibling directories (e.g., `repo/main/`, `repo/feature__foo/`).

## Dependencies

Required: `fd`, `rg` (ripgrep)
Optional: `fzf`, `bat`, `eza`, `starship`
