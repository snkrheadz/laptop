# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

macOS laptop setup repository that automates dotfiles management and package installation via Homebrew.

## Commands

```bash
# Full setup (init + link + brew install)
make setup

# Dump current installed packages to Brewfile
make brew-bundle-dump

# Install packages from Brewfile
make brew-bundle

# Link dotfiles to $HOME
make link

# Install language runtimes (via asdf)
make install-go
make install-python
make install-ruby
make install-nodejs
```

## Architecture

- `Brewfile` - Homebrew packages, casks, and VSCode extensions
- `dotfiles/` - Configuration files symlinked to `$HOME` (e.g., `.zshrc`, `.gitconfig`, `.tmux.conf`)
- `scripts/` - Setup scripts (`init.sh` installs Xcode CLI + Homebrew, `link.sh` creates symlinks)
- `zsh/` - Zsh modules symlinked to `$HOME/.zsh`
- `alacritty/` - Alacritty terminal configuration
- `bin/` - Custom executables (e.g., `tat` for tmux session management)

## Workflow

1. `scripts/init.sh` - Installs Xcode command line tools and Homebrew
2. `scripts/link.sh` - Symlinks all dotfiles from `dotfiles/` to `$HOME`, sets up zsh and alacritty configs
3. `brew bundle` - Installs all packages from Brewfile
