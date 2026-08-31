#!/usr/bin/env bash
# Claude Code status line.
#
# Claude Code pipes a JSON status payload to this script on stdin and renders
# whatever it prints below the prompt. Fields used here:
#   .model.display_name        current model
#   .context_window            token usage / % of the context window in use
#   .rate_limits.five_hour     plan usage for the rolling 5-hour session window
#   .rate_limits.seven_day     plan usage for the rolling 7-day window
#   .cost.total_cost_usd       cost of this session
# rate_limits is absent on API-key auth, so those segments are skipped when missing.

set -uo pipefail

input="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  printf 'status line needs jq (brew install jq)'
  exit 0
fi

# --- colors ---
DIM=$'\033[2m'
RESET=$'\033[0m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
BOLD=$'\033[1m'

# Green under 50% used, yellow under 80%, red above.
usage_color() {
  local pct=${1%%.*}
  if [ "$pct" -ge 80 ]; then printf '%s' "$RED"
  elif [ "$pct" -ge 50 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

# 10-cell bar, one cell per 10% used.
bar() {
  local pct=${1%%.*} filled i out=""
  [ "$pct" -lt 0 ] && pct=0
  [ "$pct" -gt 100 ] && pct=100
  filled=$((pct / 10))
  for ((i = 0; i < 10; i++)); do
    if [ "$i" -lt "$filled" ]; then out+="█"; else out+="░"; fi
  done
  printf '%s' "$out"
}

# Seconds -> "2d21h" / "2h14m" / "48m" / "now".
until_reset() {
  local ts=$1 now delta
  now=$(date +%s)
  # Payload uses epoch seconds; tolerate milliseconds just in case.
  [ "$ts" -gt 100000000000 ] && ts=$((ts / 1000))
  delta=$((ts - now))
  [ "$delta" -le 0 ] && { printf 'now'; return; }
  if [ "$delta" -ge 86400 ]; then
    printf '%dd%dh' $((delta / 86400)) $(((delta % 86400) / 3600))
  elif [ "$delta" -ge 3600 ]; then
    printf '%dh%02dm' $((delta / 3600)) $(((delta % 3600) / 60))
  else
    printf '%dm' $(((delta + 59) / 60))
  fi
}

# Unit separator, not tab: tab is IFS whitespace, so `read` would collapse empty
# fields and shift every column after a missing one.
IFS=$'\x1f' read -r cwd model ctx_pct five_pct five_reset week_pct week_reset cost <<<"$(
  jq -r '[
    (.workspace.current_dir // .cwd // ""),
    (.model.display_name // "?"),
    (.context_window.used_percentage // -1 | floor),
    (.rate_limits.five_hour.used_percentage // -1 | floor),
    (.rate_limits.five_hour.resets_at // 0 | floor),
    (.rate_limits.seven_day.used_percentage // -1 | floor),
    (.rate_limits.seven_day.resets_at // 0 | floor),
    (.cost.total_cost_usd // 0)
  ] | map(tostring) | join("\u001f")' <<<"$input" 2>/dev/null
)"

# jq failing (or an empty payload) leaves these blank; fall back to "not available".
int_or() { case "$1" in "" | *[!0-9-]*) printf '%s' "$2" ;; *) printf '%s' "$1" ;; esac; }
ctx_pct="$(int_or "$ctx_pct" -1)"
five_pct="$(int_or "$five_pct" -1)"
week_pct="$(int_or "$week_pct" -1)"
five_reset="$(int_or "$five_reset" 0)"
week_reset="$(int_or "$week_reset" 0)"
case "$cost" in "" | *[!0-9.e-]*) cost=0 ;; esac
[ -n "$model" ] || model="?"

segments=()

# Directory + git branch.
if [ -d "$cwd" ]; then
  branch="$(git -C "$cwd" branch --show-current 2>/dev/null)"
  if [ -n "$branch" ]; then
    segments+=("${CYAN}${cwd##*/}${RESET} ${DIM}⎇${RESET} ${branch}")
  else
    segments+=("${CYAN}${cwd##*/}${RESET}")
  fi
fi

segments+=("${BOLD}${model}${RESET}")

# Context window: how much of the model's window this conversation is using.
if [ "$ctx_pct" -ge 0 ]; then
  segments+=("$(usage_color "$ctx_pct")ctx ${ctx_pct}%${RESET}")
fi

# Plan limits: used %, bar, and time until the window resets.
if [ "$five_pct" -ge 0 ]; then
  seg="$(usage_color "$five_pct")5h $(bar "$five_pct") ${five_pct}%${RESET}"
  [ "$five_reset" -gt 0 ] && seg+=" ${DIM}↻$(until_reset "$five_reset")${RESET}"
  segments+=("$seg")
fi

if [ "$week_pct" -ge 0 ]; then
  seg="$(usage_color "$week_pct")wk ${week_pct}%${RESET}"
  [ "$week_reset" -gt 0 ] && seg+=" ${DIM}↻$(until_reset "$week_reset")${RESET}"
  segments+=("$seg")
fi

segments+=("${DIM}$(printf '$%.2f' "$cost")${RESET}")

out=""
for seg in "${segments[@]}"; do
  [ -n "$out" ] && out+="${DIM} · ${RESET}"
  out+="$seg"
done
printf '%s' "$out"
