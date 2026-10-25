#!/bin/sh
# Runs the Remote Control server and the idle-session reaper in tmux, and
# stops the server cleanly on `docker stop` so it can resume its sessions.
set -u

REMOTE_CONTROL_NAME=${REMOTE_CONTROL_NAME:-$(hostname)}
export REMOTE_CONTROL_NAME
WORKSPACE=${WORKSPACE:-/work}

for dir in "$HOME" "$WORKSPACE"; do
  if ! [ -w "$dir" ]; then
    echo "error: $dir is not writable by UID $(id -u):$(id -g)." >&2
    echo "Give the mounted folder to that user (chown) or change \`user:\`." >&2
    exit 1
  fi
done

# PID files from the previous container are stale and block Remote Control.
rm -f "$HOME"/.claude/sessions/*.json

# Tools, MCP servers, settings, instructions and skills from /config.
/usr/local/bin/apply-config.sh

# No --no-create-session-in-dir: without a session in the directory, a
# restarted server cannot resume the sessions it was serving.
tmux new-session -d -s remote -n remote -c "$WORKSPACE" \
  "while :; do claude remote-control --name \"\$REMOTE_CONTROL_NAME\"; [ -e /tmp/stopping ] && exit; sleep 10; done"
tmux new-window -d -t remote: -n reaper /usr/local/bin/reaper.sh

echo "Remote Control server \"$REMOTE_CONTROL_NAME\" started in tmux (session \"remote\")."

# Ctrl-C makes the server keep its sessions for the next start.
stop() {
  touch /tmp/stopping
  tmux send-keys -t remote:remote C-c
  i=0
  while pgrep -f "^claude remote-control" >/dev/null && [ "$i" -lt 20 ]; do
    sleep 1
    i=$((i + 1))
  done
  exit 0
}
trap stop TERM INT

while :; do
  sleep 3600 &
  wait $!
done
