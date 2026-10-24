#!/bin/sh
# Install the Boswell start/stop launcher into the GNOME app grid.
# Substitutes this checkout's absolute path so the icon just works.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPS="$HOME/.local/share/applications"
DEST="$APPS/boswell.desktop"

mkdir -p "$APPS"
chmod +x "$ROOT/desktop/boswell-toggle.sh"
sed "s|@BOSWELL_ROOT@|$ROOT|g" "$ROOT/desktop/boswell.desktop.in" > "$DEST"
chmod 644 "$DEST"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" || true

echo "Installed: $DEST"
echo "Find 'Boswell — Start/Stop Capture' in your app grid. Click to start, click again to stop."
