#!/bin/bash

# Exit on any error
set -e

echo "=== Clipboard Manager Installer ==="

# 1. Define paths
APP_DIR="$HOME/.config/macos-clipboard-manager"
BINARY_PATH="$APP_DIR/ClipboardManager"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENT_DIR/com.user.clipboardmanager.plist"

# 2. Create the app directory
echo "Creating application directory at: $APP_DIR"
mkdir -p "$APP_DIR"

# 3. Compile the Clipboard Manager
echo "Compiling Clipboard Manager..."
swiftc -sdk "$(xcrun --show-sdk-path -sdk macosx)" ClipboardManager.swift -o ClipboardManager

# 4. Move binary to app directory
echo "Installing binary to: $BINARY_PATH"
mv ClipboardManager "$BINARY_PATH"

# 5. Ensure default config exists
CONFIG_FILE="$APP_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating default configuration at: $CONFIG_FILE"
    cat <<EOF > "$CONFIG_FILE"
{
  "popup_key": "v",
  "popup_modifiers": ["option"],
  "cycle_key": "c",
  "cycle_modifiers": ["option"],
  "max_history": 50
}
EOF
fi

# 6. Create Launch Agent
echo "Creating Launch Agent plist at: $PLIST_PATH"
mkdir -p "$LAUNCH_AGENT_DIR"
cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.clipboardmanager</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF

# 7. Load Launch Agent
echo "Loading Launch Agent..."
# Unload first if it was already running
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "=== Clipboard Manager Installed Successfully! ==="
echo "The service is now running in the background."
echo "Default hotkeys:"
echo "- Show History Popup: Option + V"
echo "- Cycle Clipboard History: Option + C"
echo "You can customize keys at: $CONFIG_FILE"
echo "History file is stored at: $APP_DIR/history.json"
