#!/bin/bash

# Approximate RAM use % from vm_stat (wired + active + speculative + compressor pages)

PAGE_SIZE=$(vm_stat | head -1 | sed -E 's/.*page size of ([0-9]+) bytes.*/\1/')
PAGE_SIZE=${PAGE_SIZE:-16384}
TOTAL=$(sysctl -n hw.memsize)

pages() {
    vm_stat | grep "$1" | awk '{gsub(/\./,"",$NF); print $NF}'
}

wired=$(pages "Pages wired down")
active=$(pages "Pages active")
spec=$(pages "Pages speculative")
comp=$(pages "Pages occupied by compressor")

USED=$(( (wired + active + spec + comp) * PAGE_SIZE ))
if [ -z "$TOTAL" ] || [ "$TOTAL" -eq 0 ]; then
    sketchybar --set "$NAME" label="—"
    exit 0
fi
PCT=$(( USED * 100 / TOTAL ))
[ "$PCT" -gt 100 ] && PCT=100

sketchybar --set "$NAME" label="${PCT}%"
