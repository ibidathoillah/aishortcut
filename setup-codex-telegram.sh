#!/bin/bash
DIR="$(dirname "$0")/scripts/codex/setup.sh"
if [ -f "$DIR" ]; then
  exec "$DIR" "$@"
else
  TMPFILE=$(mktemp)
  curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/scripts/codex/setup.sh > "$TMPFILE"
  chmod +x "$TMPFILE"
  exec "$TMPFILE" "$@"
fi
