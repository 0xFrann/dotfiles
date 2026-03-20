#!/usr/bin/env bash
set -euo pipefail

echo "Reloading AeroSpace..."
aerospace reload-config

echo "Reloading SketchyBar..."
sketchybar --reload

echo "Reloading JankyBorders..."
brew services restart borders 2>/dev/null || true

echo "Done."
