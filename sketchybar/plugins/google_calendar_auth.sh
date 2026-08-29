#!/usr/bin/env bash
# Trigger Google Calendar OAuth re-authentication

set -euo pipefail

CFG="${CONFIG_DIR:-$HOME/.config/sketchybar}"
VPY="${CFG}/.venv/bin/python3"
[[ -x "$VPY" ]] && CAL_PY="$VPY" || CAL_PY="python3"
py="$CFG/plugins/google_calendar.py"

"$CAL_PY" "$py" --auth
sketchybar --reload
