# Git aliases and helpers (override oh-my-zsh git plugin)
unalias gco 2>/dev/null

gco() {
  local b
  b=$(git branch --format='%(refname:short)' --sort=-committerdate | fzf) || return
  git switch "$b"
}
