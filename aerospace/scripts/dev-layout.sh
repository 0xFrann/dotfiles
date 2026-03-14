#!/bin/bash
# Dev layout:
#   3 windows: IDE full-width on top (~65%), two terminals split on bottom (~35%)
#   2 windows: IDE on top (~65%), terminal on bottom (~35%)

aerospace flatten-workspace-tree
aerospace layout tiles vertical

window_count=$(aerospace list-windows --workspace focused --count)

if [ "$window_count" -gt 2 ]; then
    # Go to the bottom window
    for i in $(seq 2 "$window_count"); do
        aerospace focus down
    done
    # Move it right → creates h_tiles container with the two bottom windows
    aerospace move right
    # Focus up to the IDE window and move it up → creates v_tiles root
    aerospace focus up
    aerospace move up
fi

# Balance and resize: make top window (IDE) taller
aerospace balance-sizes
aerospace focus up
aerospace focus up
aerospace resize height +200
