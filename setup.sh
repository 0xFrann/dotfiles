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
brew services start borders 2>/dev/null || true
brew services start sketchybar 2>/dev/null || true

# --- Symlink configs ---
echo "==> Linking config files..."
"$DOTFILES_DIR/scripts/link.sh"

# --- iTerm2 color presets ---
echo "==> Importing iTerm2 color presets..."
for itermcolors in "$DOTFILES_DIR"/themes/*/*.itermcolors; do
    [ -f "$itermcolors" ] || continue
    preset="$(basename "$itermcolors" .itermcolors)"
    if /usr/libexec/PlistBuddy -c "Print ':Custom Color Presets:$preset'" ~/Library/Preferences/com.googlecode.iterm2.plist &>/dev/null; then
        echo "  $preset: already imported"
    else
        open "$itermcolors"
        echo "  $preset: imported"
    fi
done

# --- Spicetify ---
if command -v spicetify &>/dev/null; then
    echo "==> Setting up Spicetify..."
    spicetify backup apply 2>/dev/null || true
    spicetify config custom_apps marketplace 2>/dev/null || true
    spicetify apply 2>/dev/null || true
    echo "    Open Spotify and pick a theme from the Marketplace."
fi

echo ""
echo "==> Setup complete!"
echo "    Run ./scripts/switch-theme.sh to pick a color theme."
echo "    Sign into Raycast to sync your settings."
