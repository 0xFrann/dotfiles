#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
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

echo "Done."
