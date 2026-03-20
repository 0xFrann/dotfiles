#!/bin/bash
PLUGIN_DIR="$CONFIG_DIR/plugins"

args=()

all_workspaces=$(aerospace list-workspaces --all)
active_set=""

for mid in $(aerospace list-monitors | cut -c1); do
    focused=$(aerospace list-workspaces --monitor "$mid" --visible)
    for sid in $(aerospace list-workspaces --monitor "$mid"); do
        active_set+=" $sid "
        apps=$(aerospace list-windows --workspace "$sid" | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')

        icon_strip=" "
        if [ -n "$apps" ]; then
            while read -r app; do
                icon_strip+=" $($PLUGIN_DIR/icon_map_fn.sh "$app")"
            done <<<"${apps}"
        else
            icon_strip=""
        fi

        has_windows=$( [ -n "$apps" ] && echo "on" || echo "off" )
        is_focused=$( [ "$sid" = "$focused" ] && echo "on" || echo "$has_windows" )

        args+=(--set space.$sid display=$mid drawing=$is_focused label="$icon_strip")
    done
done

for sid in $all_workspaces; do
    if [[ "$active_set" != *" $sid "* ]]; then
        args+=(--set space.$sid drawing=off)
    fi
done

for sid in T1 T2 T3; do
    if [[ "$active_set" != *" $sid "* ]]; then
        args+=(--set space.$sid drawing=off)
    fi
done

sketchybar "${args[@]}"
