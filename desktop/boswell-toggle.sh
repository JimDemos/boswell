#!/bin/sh
# Boswell GUI toggle — one click starts capture, the next click stops it.
# Wraps boswellctl so the button and the CLI are the same thing.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CTL="$ROOT/boswellctl"
TSDIR="${BOSWELL_TRANSCRIPTS:-$HOME/boswell-transcripts}"
mkdir -p "$TSDIR"

notify() { command -v notify-send >/dev/null 2>&1 && notify-send -a Boswell "$1" "$2" || true; }

if info="$("$CTL" status 2>/dev/null)" && printf '%s' "$info" | grep -q '^running'; then
  # Currently capturing -> stop
  file="$(printf '%s' "$info" | sed -n 's/.*file=\([^ ]*\).*/\1/p')"
  "$CTL" stop >/dev/null 2>&1 || true
  notify "Boswell stopped" "Transcript: ${file:-saved}"
else
  # Stopped -> start (CPU int8 by default; small.en is snappy on a laptop)
  file="$TSDIR/$(date +%Y%m%d-%H%M%S).txt"
  "$CTL" start --model small.en --file "$file" >/dev/null 2>&1 || true
  notify "Boswell capturing" "Recording desktop audio. Click again to stop."
fi
