#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

DEST="/Applications/Poof.app"
echo "Installing to $DEST..."
rm -rf "$DEST"
cp -R "Poof.app" "$DEST"

PLIST="$HOME/Library/LaunchAgents/com.poof.recorder.plist"
echo "Writing LaunchAgent $PLIST..."
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.poof.recorder</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/Poof.app/Contents/MacOS/poof</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>$HOME/Library/Logs/poof.log</string>
    <key>StandardErrorPath</key><string>$HOME/Library/Logs/poof.log</string>
</dict>
</plist>
EOF

echo "Loading LaunchAgent..."
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "Installed. Poof is running (menu bar). Grant Screen Recording on first ⌘⇧2 if prompted."
