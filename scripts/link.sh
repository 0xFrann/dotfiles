#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$HOME/.config"

mkdir -p "$CONFIG_DIR"

echo "Cleaning stale symlinks in $CONFIG_DIR"

for link in "$CONFIG_DIR"/*; do
  [ -L "$link" ] || continue
  target="$(readlink "$link")"
  case "$target" in
    "$DOTFILES_DIR"/*) 
      if [ ! -e "$link" ]; then
        echo "  $(basename "$link"): removed (no longer in dotfiles)"
        rm "$link"
      fi
      ;;
  esac
done

echo "Linking dotfiles from $DOTFILES_DIR -> $CONFIG_DIR"

for dir in "$DOTFILES_DIR"/*/; do
  name="$(basename "$dir")"
  [[ "$name" =~ ^(claude|cursor|iterm2|scripts|themes|zsh)$ ]] && continue
  target="$CONFIG_DIR/$name"

  if [ -L "$target" ]; then
    echo "  $name: already linked, updating"
    rm "$target"
  elif [ -e "$target" ]; then
    echo "  $name: backing up existing $target -> $target.bak"
    mv "$target" "$target.bak"
  fi

  ln -s "$dir" "$target"
  echo "  $name: linked"
done

# zsh: ~/.zshrc must live in $HOME, not ~/.config
ZSHRC_SRC="$DOTFILES_DIR/zsh/.zshrc"
ZSHRC_DST="$HOME/.zshrc"

if [ -f "$ZSHRC_SRC" ]; then
  if [ -L "$ZSHRC_DST" ]; then
    echo "  .zshrc: already linked, updating"
    rm "$ZSHRC_DST"
  elif [ -e "$ZSHRC_DST" ]; then
    echo "  .zshrc: backing up existing $ZSHRC_DST -> $ZSHRC_DST.bak"
    mv "$ZSHRC_DST" "$ZSHRC_DST.bak"
  fi
  ln -s "$ZSHRC_SRC" "$ZSHRC_DST"
  echo "  .zshrc: linked"
fi

# Claude Code: settings live in ~/.claude and Claude rewrites them, so merge our
# keys into the existing file instead of symlinking it.
CLAUDE_SRC="$DOTFILES_DIR/claude"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

if [ -d "$CLAUDE_SRC" ] && command -v jq &>/dev/null; then
  echo "Configuring Claude Code status line"
  mkdir -p "$HOME/.claude"
  [ -f "$CLAUDE_SETTINGS" ] || echo '{}' > "$CLAUDE_SETTINGS"
  tmp="$(mktemp)"
  jq --slurpfile add "$CLAUDE_SRC/settings.partial.json" '. * $add[0]' "$CLAUDE_SETTINGS" > "$tmp" \
    && mv "$tmp" "$CLAUDE_SETTINGS"
  echo "  statusLine: configured"
fi

# Cursor/VSCode: symlink individual files into Application Support
CURSOR_SRC="$DOTFILES_DIR/cursor"
CURSOR_DST="$HOME/Library/Application Support/Cursor/User"

if [ -d "$CURSOR_SRC" ]; then
  mkdir -p "$CURSOR_DST"
  echo "Linking Cursor config from $CURSOR_SRC -> $CURSOR_DST"

  for file in "$CURSOR_SRC"/*.json; do
    [ -f "$file" ] || continue
    name="$(basename "$file")"
    target="$CURSOR_DST/$name"

    if [ -L "$target" ]; then
      echo "  $name: already linked, updating"
      rm "$target"
    elif [ -e "$target" ]; then
      echo "  $name: backing up existing $target -> $target.bak"
      mv "$target" "$target.bak"
    fi

    ln -s "$file" "$target"
    echo "  $name: linked"
  done

  if [ -f "$CURSOR_SRC/extensions.txt" ] && command -v cursor &>/dev/null; then
    echo "Installing Cursor extensions..."
    while read -r ext; do
      cursor --install-extension "$ext" --force 2>/dev/null &
    done < "$CURSOR_SRC/extensions.txt"
    wait
    echo "  extensions installed"
  fi
fi

echo "Done."
