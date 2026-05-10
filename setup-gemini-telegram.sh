#!/bin/bash
DIR="$(dirname "$0")/scripts/gemini/setup.sh"
if [ -f "$DIR" ]; then
  exec "$DIR" "$@"
else
  TMPFILE=$(mktemp)
  curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/scripts/gemini/setup.sh > "$TMPFILE"
  chmod +x "$TMPFILE"
  exec "$TMPFILE" "$@"
fi
