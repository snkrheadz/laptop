#!/bin/bash
# zsh
ln -sf $(pwd)/zsh $HOME/.zsh
# dotfiles
find dotfiles -name ".*" -type f | xargs -I{} ln -sf $(pwd)/{} $HOME
