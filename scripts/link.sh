#!/bin/bash
DOTFILES_DIR=$(pwd)"/dotfiles/*"
ln -s $(pwd)"/dotfiles/*" $HOME

# zsh
ln -s $(pwd)"/zsh" $HOME/.zsh
