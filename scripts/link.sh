#!/bin/bash
# zsh
ln -sf $(pwd)/zsh $HOME/.zsh
# dotfiles
find dotfiles -name ".*" -type f | xargs -I{} ln -sf $(pwd)/{} $HOME
# alacritty
mkdir -p $HOME/.config/alacritty/themes
if [ ! -d "$HOME/.config/alacritty/themes" ]; then
    git clone https://github.com/alacritty/alacritty-theme $HOME/.config/alacritty/themes
fi
if [ ! -f "$HOME/.config/alacritty/alacritty.toml" ]; then
    ln -sf $(pwd)/alacritty/alacritty.toml $HOME/.config/alacritty/alacritty.toml
fi
