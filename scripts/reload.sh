#!/usr/bin/env bash
set -euo pipefail

echo "Reloading AeroSpace..."
aerospace reload-config

echo "Reloading SketchyBar..."
sketchybar --reload

echo "Done."
