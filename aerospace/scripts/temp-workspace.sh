#!/bin/bash
MONITOR=$(aerospace list-monitors --focused | cut -c1)
case "$MONITOR" in
    1) WS="T1" ;;
    2) WS="T2" ;;
    3) WS="T3" ;;
    *) WS="T1" ;;
esac

if [ "$1" = "move" ]; then
    aerospace move-node-to-workspace "$WS"
    sketchybar --trigger aerospace_workspace_change \
        FOCUSED_WORKSPACE="$(aerospace list-workspaces --focused)"
else
    aerospace workspace "$WS"
fi
