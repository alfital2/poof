#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

DEST="/Applications/Poof.app"
echo "Installing to $DEST..."
rm -rf "$DEST"
cp -R "Poof.app" "$DEST"

echo "Launching Poof..."
open "$DEST"

echo
echo "Installed. A scissors-of-smoke icon is in the menu bar."
echo "  • Grant Screen Recording on first ⌘⇧2 if prompted."
echo "  • Turn on autostart from the menu: Poof ▸ Launch at Login."
