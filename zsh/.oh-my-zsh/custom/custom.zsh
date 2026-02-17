# Homebrew (macOS only)
if [[ "$(uname)" == "Darwin" ]] && command -v /opt/homebrew/bin/brew &>/dev/null; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export HOMEBREW_NO_INSECURE_REDIRECT=1
  export HOMEBREW_CASK_OPTS=--require-sha
  export HOMEBREW_DIR=/opt/homebrew
  export HOMEBREW_BIN=/opt/homebrew/bin

  # Prefer GNU binaries to macOS binaries
  export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
fi

# Python shims (if pyenv is installed)
command -v pyenv &>/dev/null && eval "$(pyenv init -)"

# Ruby shims (if rbenv is installed)
command -v rbenv &>/dev/null && eval "$(rbenv init -)"

# Add datadog devtools binaries to the PATH
export PATH="$HOME/dd/devtools/bin:$PATH"

# Point GOPATH to our go sources
export GOPATH="$HOME/go"

# Add binaries that are go install-ed to PATH
export PATH="$GOPATH/bin:$PATH"

# Point DATADOG_ROOT to ~/dd symlink
export DATADOG_ROOT="$HOME/dd"

# Tell the devenv vm to mount $GOPATH/src rather than just dd-go
export MOUNT_ALL_GO_SRC=1

# store key in the login keychain instead of aws-vault managing a hidden keychain
export AWS_VAULT_KEYCHAIN_NAME=login

# tweak session times so you don't have to re-enter passwords every 5min
export AWS_SESSION_TTL=24h
export AWS_ASSUME_ROLE_TTL=1h

# Helm switch from storing objects in kubernetes configmaps to
# secrets by default, but we still use the old default.
export HELM_DRIVER=configmap

# Go module settings
export GO111MODULE=auto
export GOPRIVATE=github.com/DataDog
export GOPROXY=binaries.ddbuild.io,https://proxy.golang.org,direct
export GONOSUMDB=github.com/DataDog,go.ddbuild.io

# Gitsign (macOS only, uses keychain)
[ -f ~/.config/gitsign/include.sh ] && source ~/.config/gitsign/include.sh

# Source .env if it exists (for local secrets)
[ -f ~/.env ] && source ~/.env

# Aliases
alias k=kubectl
