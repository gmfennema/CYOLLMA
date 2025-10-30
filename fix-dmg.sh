#!/bin/bash

# Remove quarantine attribute from CYOLLMA DMG
# Run this script after downloading CYOLLMA-app.dmg from GitHub

DMG_PATH="$HOME/Downloads/CYOLLMA-app.dmg"

if [ ! -f "$DMG_PATH" ]; then
    echo "❌ CYOLLMA-app.dmg not found in Downloads folder."
    echo "   Please make sure you've downloaded it to: $DMG_PATH"
    exit 1
fi

echo "🔓 Removing quarantine attribute from CYOLLMA-app.dmg..."
xattr -d com.apple.quarantine "$DMG_PATH" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Quarantine attribute removed successfully!"
    echo "   You can now open the DMG file normally."
else
    echo "⚠️  No quarantine attribute found (or already removed)."
    echo "   Try opening the DMG file now."
fi

