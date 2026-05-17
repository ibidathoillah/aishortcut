#!/bin/bash
DIR="$(dirname "$0")/scripts/claude/setup.sh"
if [ -f "$DIR" ]; then
  exec "$DIR" "$@"
else
  TMPFILE=$(mktemp)
  curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/scripts/claude/setup.sh > "$TMPFILE"
  chmod +x "$TMPFILE"
  exec "$TMPFILE" "$@"
fi
