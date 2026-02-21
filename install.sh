#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install stow if not available
if ! command -v stow &>/dev/null; then
  echo "Installing stow..."
  if [[ "$(uname)" == "Darwin" ]]; then
    brew install stow
  else
    sudo apt-get update -qq && sudo apt-get install -y -qq stow
  fi
fi

# Install oh-my-zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Stow each package, overriding any existing files
cd "$DOTFILES_DIR"
# Stash uncommitted work so adopt+checkout cycle doesn't destroy it
git stash --quiet 2>/dev/null; had_stash=$?

for pkg in claude zsh git gh; do
  if [ -d "$pkg" ]; then
    echo "Stowing $pkg..."
    stow --adopt -t "$HOME" "$pkg"
    # adopt pulls existing $HOME files into our tree; reset to committed state
    git checkout -- "$pkg"
  fi
done

# Restore uncommitted work
if [ "$had_stash" -eq 0 ]; then
  git stash pop --quiet
fi

echo "Dotfiles installed."
