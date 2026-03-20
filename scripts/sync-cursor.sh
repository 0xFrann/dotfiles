#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CURSOR_DIR="$DOTFILES_DIR/cursor"

if command -v cursor &>/dev/null; then
    cursor --list-extensions > "$CURSOR_DIR/extensions.txt"
    echo "Updated extensions.txt ($(wc -l < "$CURSOR_DIR/extensions.txt") extensions)"
else
    echo "Warning: cursor CLI not found, skipping extensions"
fi

echo "Done."
