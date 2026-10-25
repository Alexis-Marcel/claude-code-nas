#!/bin/sh
# Healthy while the Remote Control server process is running.
pgrep -f "^claude remote-control" >/dev/null
