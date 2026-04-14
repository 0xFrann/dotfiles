#!/usr/bin/env bash
# Set up Google Calendar integration for SketchyBar (one-time, per machine).
#
# What this does:
#   1. Checks that google_calendar_credentials.json exists
#   2. Creates a Python venv and installs API dependencies
#   3. Opens a browser for Google OAuth login
#   4. Saves the token and reloads SketchyBar
#
# Prerequisites:
#   - Download OAuth credentials JSON from Google Cloud Console
#     (Calendar API enabled, Desktop app client) and save as:
#     ~/.config/sketchybar/google_calendar_credentials.json
set -euo pipefail

CFG="${HOME}/.config/sketchybar"
VEN="${CFG}/.venv"
CRED="${CFG}/google_calendar_credentials.json"
PY="${CFG}/plugins/google_calendar.py"

if [[ ! -f "$CRED" ]]; then
    echo "Missing: ${CRED}"
    echo ""
    echo "Go to https://console.cloud.google.com/ and:"
    echo "  1. Create a project (or pick an existing one)"
    echo "  2. Enable the Google Calendar API"
    echo "  3. Credentials → Create credentials → OAuth client ID → Desktop app"
    echo "  4. Download the JSON and save it as:"
    echo "       ${CRED}"
    echo "  5. Run this script again"
    exit 1
fi

echo "==> Creating venv and installing dependencies…"
python3 -m venv "${VEN}"
"${VEN}/bin/pip" install --quiet --upgrade pip
"${VEN}/bin/pip" install --quiet google-auth-oauthlib google-api-python-client
echo "    Installed into ${VEN}"

echo ""
echo "==> Opening browser for Google Calendar login…"
"${VEN}/bin/python3" "${PY}" --auth

CONF="${CFG}/google_calendar_config.json"
echo ""
echo "==> Your calendars:"
"${VEN}/bin/python3" "${PY}" --list-calendars

if [[ ! -f "$CONF" ]]; then
    echo '{"exclude": []}' > "${CONF}"
    echo ""
    echo "    Created ${CONF}"
fi
echo ""
echo "    To hide calendars, add their names to ${CONF}:"
echo '    {"exclude": ["OOO", "Holidays in Argentina"]}'

echo ""
echo "==> Reloading SketchyBar…"
sketchybar --reload
echo "    Calendar events should appear shortly."
