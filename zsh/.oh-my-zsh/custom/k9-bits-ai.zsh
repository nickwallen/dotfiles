# ~/.oh-my-zsh/custom/chatbot.zsh
#
# Usage quickstart:
#   hotdog-use US1
#   hotdog-status
#   hotdog-deploy
#   hotdog-update
#   hotdog-shell
#   hotdog-logs

# Remove legacy hotdog / cluster aliases (migration from alias → function)
unalias \
  hotdog-cluster \
  hotdog-clirun \
  hotdog-deploy \
  hotdog-update \
  hotdog-bash \
  hotdog-shell \
  hotdog-delete \
  hotdog-logs \
  hotdog-status \
  2>/dev/null

NAMESPACE="chatbot"
DEPLOYMENT="chatbot-cli-hotdog-${USER//./}-fast-dev"

# Map region to cluster name
_hotdog_cluster() {
  case "${1:u}" in
    US1) echo "centurion.us1.prod.dog" ;;
    EU1) echo "skrelp.eu1.prod.dog" ;;
    US5) echo "nidoking.us5.prod.dog" ;;
    US3) echo "zekrom.us3.prod.dog" ;;
    AP1) echo "whiscash.ap1.prod.dog" ;;
    AP2) echo "espathra.ap2.prod.dog" ;;
    *)   return 1 ;;
  esac
}

# Resolve current git worktree root (fallback to ~/dd/dd-source)
_dd_repo_root() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/dd/dd-source")"
  echo "hotdog: using repo at $root" >&2
  echo "$root"
}

# Show current kubectl context with region name
hotdog-cluster() {
  local ctx
  ctx="$(kubectl config current-context)" || return $?
  # Extract region from context (e.g., "us1" from "centurion.us1.prod.dog")
  local region="${ctx#*.}"      # remove prefix up to first dot
  region="${region%%.*}"        # remove suffix from first dot
  echo "hotdog: using ${region} (${ctx})"
}

# Show full hotdog status
hotdog-status() {
  local ctx repo image state kctl

  if [[ -n "$1" ]]; then
    ctx="$(_hotdog_cluster "$1")" || { echo "Unknown region: $1"; return 1; }
    kctl="kubectl --context=$ctx"
  else
    ctx="$(kubectl config current-context 2>/dev/null)" || { echo "cluster: (not set)"; return 1; }
    kctl="kubectl"
  fi

  # Only use git root if it's a dd-source repo
  repo="$(git rev-parse --show-toplevel 2>/dev/null)"
  [[ "$repo" == *dd-source* ]] || repo="$HOME/dd/dd-source"

  # Check if deployment exists
  if $kctl get deployment "$DEPLOYMENT" -n "$NAMESPACE" &>/dev/null; then
    # Extract fields using jsonpath
    image="$($kctl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
      -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)"
    # Truncate image to tag or short digest
    if [[ "$image" == *@sha256:* ]]; then
      image="${image##*@sha256:}"
      image="${image:0:12}"
    else
      image="${image##*:}"
    fi

    local ready_rep replicas started created
    ready_rep="$($kctl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
      -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
    replicas="$($kctl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
      -o jsonpath='{.status.replicas}' 2>/dev/null)"
    created="$($kctl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
      -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)"
    # Get container startedAt from pod
    started="$($kctl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT" \
      -o jsonpath='{.items[0].status.containerStatuses[0].state.running.startedAt}' 2>/dev/null)"

    ready_rep="${ready_rep:-0}"
    replicas="${replicas:-0}"

    local now=$(date +%s)

    # Image age from container startedAt
    local image_age="-"
    if [[ -n "$started" ]]; then
      local then=$(date -d "$started" +%s 2>/dev/null)
      if [[ -n "$then" ]]; then
        local diff=$((now - then))
        if (( diff < 3600 )); then image_age="$((diff / 60))m"
        elif (( diff < 86400 )); then image_age="$((diff / 3600))h"
        else image_age="$((diff / 86400))d"; fi
      fi
    fi
    image="$image (up $image_age)"

    # Deployment age from creationTimestamp
    local deploy_age="-"
    if [[ -n "$created" ]]; then
      local then=$(date -d "$created" +%s 2>/dev/null)
      if [[ -n "$then" ]]; then
        local diff=$((now - then))
        if (( diff < 3600 )); then deploy_age="$((diff / 60))m"
        elif (( diff < 86400 )); then deploy_age="$((diff / 3600))h"
        else deploy_age="$((diff / 86400))d"; fi
      fi
    fi
    state="Running ${ready_rep}/${replicas}, up ${deploy_age}"
  else
    image="-"
    state="Not deployed"
  fi

  printf "cluster:    %s\n" "$ctx"
  printf "namespace:  %s\n" "$NAMESPACE"
  printf "deployment: %s\n" "$DEPLOYMENT"
  printf "image:      %s\n" "$image"
  printf "status:     %s\n" "$state"
  printf "repo:       %s\n" "$repo"
}

# Switch cluster using short region name (US1, EU1, etc)
hotdog-use() {
  local cluster
  cluster="$(_hotdog_cluster "$1")" || { echo "Usage: hotdog-use {us1|eu1|us3|us5|ap1|ap2}"; return 2; }
  ddtool clusters use "$cluster"
}

# Run chatbot clirun from current worktree
hotdog-clirun() {
  hotdog-cluster || return $?
  local root="$(_dd_repo_root)"
  ( cd "$root" &&
    "$root/domains/chatbot/scripts/clirun" \
      -l -d "${USER//./}-fast-dev" \
      -- security_agent "$@" )
}

# Deploy chatbot hotdog from current worktree
hotdog-deploy() {
  hotdog-cluster || return $?
  local root="$(_dd_repo_root)"
  ( cd "$root" &&
    "$root/domains/chatbot/dev/hotdog-deploy" \
      chatbot-cli "${USER//./}" --fast --debug "$@" )
}

# Update chatbot hotdog from current worktree
hotdog-update() {
  hotdog-cluster || return $?
  local root="$(_dd_repo_root)"
  ( cd "$root" &&
    "$root/domains/chatbot/dev/hotdog-update" \
      chatbot-cli "${USER//./}" --fast --debug "$@" )
}

# Exec bash in chatbot-cli container
hotdog-bash() {
  hotdog-cluster || return $?
  kubectl exec -it \
    "deployments/$DEPLOYMENT" \
    -n "$NAMESPACE" \
    -c chatbot-cli \
    -- bash
}

# Alternate shell exec into chatbot-cli
hotdog-shell() {
  hotdog-cluster || return $?
  kubectl -n "$NAMESPACE" exec -it \
    "deployment/$DEPLOYMENT" \
    -- bash
}

# Delete chatbot hotdog deployment
hotdog-delete() {
  hotdog-cluster || return $?
  kubectl delete deployment \
    --namespace "$NAMESPACE" \
    "$DEPLOYMENT"
}

# Open Datadog logs for chatbot hotdog
hotdog-logs() {
  open "https://app.datadoghq.com/logs?query=service%3Achatbot-cli%20kube_deployment%3A${DEPLOYMENT}"
}
