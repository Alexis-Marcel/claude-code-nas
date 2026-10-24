#!/bin/sh
# Stops (SIGTERM) app-spawned sessions whose CPU time has not changed for
# IDLE_MIN minutes, to free their memory. The server treats them as crashed
# and restarts them on the next message.
set -u

IDLE_MIN=${IDLE_MIN:-60}
REAPER_INTERVAL=${REAPER_INTERVAL:-600}
STATE=/tmp/reaper
mkdir -p "$STATE"

while :; do
  for pid in $(pgrep -f -- "--sdk-url"); do
    cpu=$(ps -o times= -p "$pid" | tr -d " ")
    [ -n "$cpu" ] || continue
    f=$STATE/$pid
    if ! [ -f "$f" ] || [ "$(cat "$f")" != "$cpu" ]; then
      echo "$cpu" > "$f"
    elif [ -n "$(find "$f" -mmin +"$IDLE_MIN")" ]; then
      echo "$(date "+%F %T") stopping idle session $pid"
      kill "$pid"
      rm -f "$f"
    fi
  done
  # Forget sessions that are gone.
  for f in "$STATE"/*; do
    [ -e "$f" ] || continue
    kill -0 "${f##*/}" 2>/dev/null || rm -f "$f"
  done
  sleep "$REAPER_INTERVAL"
done
