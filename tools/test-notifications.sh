#!/usr/bin/env bash
set -e

echo "=== AOD4KDE Notifications Test ==="
echo "1. Sending test notifications with native system icons..."

notify-send -a "Telegram" -i "org.telegram.desktop" "Telegram" "New message from Marco"
sleep 0.3
notify-send -a "Spectacle" -i "spectacle" "Screenshot captured" "Image saved to Pictures"
sleep 0.3
notify-send -a "Waterfox" -i "net.waterfox.waterfox" "Download finished" "Arch Linux ISO downloaded"
sleep 0.3
notify-send -a "Chrome" -i "com.google.Chrome" "Google Chrome" "Update available"

sleep 0.5
echo ""
echo "2. Current notifications file status ($XDG_RUNTIME_DIR/aod-notifications.json):"
if [ -f "$XDG_RUNTIME_DIR/aod-notifications.json" ]; then
    cat "$XDG_RUNTIME_DIR/aod-notifications.json"
    echo ""
elif [ -f "$HOME/.cache/aod-notifications.json" ]; then
    cat "$HOME/.cache/aod-notifications.json"
    echo ""
fi

echo ""
echo "AOD lockscreen preview:"
echo "    /usr/lib/kscreenlocker_greet --testing"
