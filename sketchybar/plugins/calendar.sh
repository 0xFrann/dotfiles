#!/usr/bin/env bash
# Next calendar event today (Google Calendar API + OAuth, readonly).
# SketchyBar runs this on a timer. One-time setup: ./scripts/setup-google-calendar.sh

set -euo pipefail

CFG="${CONFIG_DIR:-$HOME/.config/sketchybar}"
VPY="${CFG}/.venv/bin/python3"
[[ -x "$VPY" ]] && CAL_PY="$VPY" || CAL_PY="python3"
py="$CFG/plugins/google_calendar.py"
line="$("$CAL_PY" "$py" || true)"
[[ -z "$line" ]] && line="—"

if [[ "$line" == *$'\t'* ]]; then
  label="${line%%$'\t'*}"
  cnt="${line#*$'\t'}"
  sketchybar --set next_event_meta \
    icon="󰃭" \
    label="($cnt)" \
    label.drawing=on
  sketchybar --set next_event label="$label"
else
  sketchybar --set next_event_meta \
    icon="󰃭" \
    label="" \
    label.drawing=off
  sketchybar --set next_event label="$line"
fi
