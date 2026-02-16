#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install stow if not available
if ! command -v stow &>/dev/null; then
  echo "Installing stow..."
  sudo apt-get update -qq && sudo apt-get install -y -qq stow
fi

# Install oh-my-zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Stow each package, overriding any existing files
cd "$DOTFILES_DIR"
for pkg in claude zsh git; do
  if [ -d "$pkg" ]; then
    echo "Stowing $pkg..."
    stow --adopt -t "$HOME" "$pkg"
    # adopt pulls existing files into our tree; restore ours
    git checkout -- "$pkg"
  fi
done

echo "Dotfiles installed."
