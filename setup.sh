#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> macOS dotfiles setup"

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
    echo "==> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to PATH for Apple Silicon Macs
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "==> Homebrew already installed"
fi

# --- Dependencies ---
echo "==> Installing packages from Brewfile..."
brew bundle --file="$DOTFILES_DIR/Brewfile"

# --- Services ---
echo "==> Starting services..."
brew services start sketchybar 2>/dev/null || true

# --- Symlink configs ---
echo "==> Linking config files..."
"$DOTFILES_DIR/scripts/link.sh"

echo ""
echo "==> Setup complete!"
echo "    Run ./scripts/switch-theme.sh to pick a color theme."
