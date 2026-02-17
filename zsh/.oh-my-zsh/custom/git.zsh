# Git aliases and helpers (override oh-my-zsh git plugin)
unalias gb gco 2>/dev/null

alias gb='git branch --format="%(refname:short)" --sort=-committerdate'

gco() {
  local b
  b=$(git branch --format='%(refname:short)' --sort=-committerdate | fzf) || return
  git switch "$b"
}
