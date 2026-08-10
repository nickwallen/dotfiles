#
# See ~/.oh-my-zsh/custom/custom.zsh for custom stuff!!!
#

# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
plugins=(git)

source $ZSH/oh-my-zsh.sh

# Warn if gh CLI is not authenticated
if command -v gh &>/dev/null && ! gh auth status &>/dev/null 2>&1; then
  echo "⚠ gh CLI not authenticated. Run: gh auth login"
fi

# Prompt: show host label to distinguish local from workspace
if [[ "$HOME" == "/home/bits" ]]; then
  _host_label="%m"
else
  _host_label="local"
fi
PROMPT="%F{cyan}${_host_label}%f $PROMPT"

# SDKMAN (conditional)
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

source "$HOME/.yarn/switch/env"

# Colima Docker socket (for Testcontainers)
export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock

# Trajectory - AI coding agent observability
export PATH="/Users/nick.allen/.trajectory/bin:$PATH"

# Default editor (used by opencode /editor and /export)
export EDITOR="vim"
