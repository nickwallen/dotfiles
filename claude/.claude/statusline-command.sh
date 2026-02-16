#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# ANSI color codes (will be dimmed by Claude)
CYAN='\033[36m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
BLUE='\033[34m'
MAGENTA='\033[35m'
RESET='\033[0m'

# Extract current directory and replace home with ~
cwd=$(echo "$input" | jq -r '.cwd')
dir=$(echo "$cwd" | sed "s|^$HOME|~|")

# Replace DataDog path with ~/dd
dir=$(echo "$dir" | sed 's|^~/go/src/github\.com/DataDog|~/dd|')

# Build status line output with colored directory
output="${YELLOW}${dir}${RESET}"

# Add git branch if in git repo (in red)
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

  # Truncate branch name if longer than 30 characters
  if [ "${#branch}" -gt 30 ]; then
    branch="..${branch: -30}"
  fi

  # Check for dirty working tree and get file/line stats
  if git -C "$cwd" --no-optional-locks diff-index --quiet HEAD 2>/dev/null; then
    dirty_indicator="✓"
    dirty_stats=""
  else
    dirty_indicator="✗"
    # Get stats for uncommitted changes (staged + unstaged)
    stats=$(git -C "$cwd" --no-optional-locks diff HEAD --shortstat 2>/dev/null)
    if [ -n "$stats" ]; then
      files=$(echo "$stats" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+')
      insertions=$(echo "$stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
      deletions=$(echo "$stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')
      [ -z "$files" ] && files=0
      [ -z "$insertions" ] && insertions=0
      [ -z "$deletions" ] && deletions=0
      dirty_stats=" ${files}f +${insertions} -${deletions}"
    else
      dirty_stats=""
    fi
  fi

  # Check ahead/behind remote
  ahead_behind=""
  upstream=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref @{upstream} 2>/dev/null)
  if [ -n "$upstream" ]; then
    ahead=$(git -C "$cwd" --no-optional-locks rev-list --count HEAD@{upstream}..HEAD 2>/dev/null || echo "0")
    behind=$(git -C "$cwd" --no-optional-locks rev-list --count HEAD..HEAD@{upstream} 2>/dev/null || echo "0")

    if [ "$ahead" -gt 0 ]; then
      ahead_behind="${ahead_behind}↑${ahead}"
    fi
    if [ "$behind" -gt 0 ]; then
      ahead_behind="${ahead_behind}↓${behind}"
    fi
  fi

  output="$output │ ${CYAN}ƒ $branch $dirty_indicator${dirty_stats}${ahead_behind}${RESET}"
fi

# Add context usage percentage with icon (color based on usage)
used_percent=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used_percent" ]; then
  # Round to integer
  used_int=$(printf "%.0f" "$used_percent")

  # Choose icon and color based on percentage
  if [ "$used_int" -lt 20 ]; then
    icon="○"
    color="$GREEN"
  elif [ "$used_int" -lt 40 ]; then
    icon="◔"
    color="$GREEN"
  elif [ "$used_int" -lt 60 ]; then
    icon="◑"
    color="$YELLOW"
  elif [ "$used_int" -lt 80 ]; then
    icon="◕"
    color="$YELLOW"
  else
    icon="●"
    color="$RED"
  fi

  output="$output │ ${color}${icon} ${used_int}%${RESET}"
fi

# Add model name (simplified) in blue
model_id=$(echo "$input" | jq -r '.model.id')
if [[ "$model_id" == *"opus"* ]]; then
  model_name="opus-4-5"
elif [[ "$model_id" == *"sonnet"* ]]; then
  model_name="sonnet-4-5"
else
  model_name=$(echo "$input" | jq -r '.model.display_name' | awk '{print tolower($1"-"$2)}')
fi
output="$output │ ${BLUE}○ $model_name${RESET}"

# Add cost tracker (using cumulative session totals)
input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# Only show cost if we have token data
if [ "$input_tokens" -gt 0 ] || [ "$output_tokens" -gt 0 ]; then
  # Calculate cost based on model (prices per million tokens)
  if [[ "$model_id" == *"opus"* ]]; then
    # Opus 4.5: $15 input, $75 output per million tokens
    cost=$(echo "scale=6; ($input_tokens * 15 + $output_tokens * 75) / 1000000" | bc)
  elif [[ "$model_id" == *"sonnet"* ]]; then
    # Sonnet 4.5: $3 input, $15 output per million tokens
    cost=$(echo "scale=6; ($input_tokens * 3 + $output_tokens * 15) / 1000000" | bc)
  else
    cost="0"
  fi

  # Format cost display
  if [ "$cost" != "0" ]; then
    # If less than $0.01, show in cents
    if (( $(echo "$cost < 0.01" | bc -l) )); then
      cost_cents=$(printf "%.1f" $(echo "$cost * 100" | bc))
      output="$output │ ${MAGENTA}${cost_cents}¢${RESET}"
    else
      cost_display=$(printf "%.2f" "$cost")
      output="$output │ ${MAGENTA}\$${cost_display}${RESET}"
    fi
  fi
fi

printf "%b" "$output"
