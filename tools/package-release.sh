#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCH="$(uname -m)"
DIST_DIR="$REPO_DIR/dist"
STAGE_DIR="$DIST_DIR/aod4kde"
ARCHIVE_NAME="aod4kde-linux-${ARCH}.tar.gz"

echo "=========================================="
echo "   AOD4KDE - Pre-built Release Packager"
echo "=========================================="

# 1. Build all binaries and translations
echo "==> 1/3 Building C++ binaries and translations..."
make -C "$REPO_DIR" all

# 2. Stage clean release directory (no C++ sources, Makefiles, or .po files)
echo "==> 2/3 Staging release files in $STAGE_DIR..."
rm -rf "$STAGE_DIR"
mkdir -p \
    "$STAGE_DIR/src/tray" \
    "$STAGE_DIR/src/helper" \
    "$STAGE_DIR/src/settings/components" \
    "$STAGE_DIR/src/lockscreen/custom-aod/components" \
    "$STAGE_DIR/assets" \
    "$STAGE_DIR/src/extensions/io.github.aod4kde.notifications/bin" \
    "$STAGE_DIR/src/extensions/io.github.aod4kde.sensors/bin"

# Mark as pre-built so install.sh skips compilation
touch "$STAGE_DIR/.prebuilt"

# Copy scripts and license
install -m 644 "$REPO_DIR/LICENSE" "$STAGE_DIR/LICENSE"
install -m 755 "$REPO_DIR/install.sh" "$STAGE_DIR/install.sh"
install -m 755 "$REPO_DIR/uninstall.sh" "$STAGE_DIR/uninstall.sh"

# Copy and strip compiled binaries
install -s -m 755 "$REPO_DIR/src/tray/aod-tray" "$STAGE_DIR/src/tray/aod-tray"
install -s -m 755 "$REPO_DIR/src/helper/aod-helper" "$STAGE_DIR/src/helper/aod-helper"
install -s -m 755 "$REPO_DIR/src/settings/aod-settings" "$STAGE_DIR/src/settings/aod-settings"
install -s -m 755 "$REPO_DIR/src/extensions/io.github.aod4kde.notifications/bin/aod-ext-notifications" \
    "$STAGE_DIR/src/extensions/io.github.aod4kde.notifications/bin/aod-ext-notifications"
install -s -m 755 "$REPO_DIR/src/extensions/io.github.aod4kde.sensors/bin/aod-ext-sensors" \
    "$STAGE_DIR/src/extensions/io.github.aod4kde.sensors/bin/aod-ext-sensors"

# Copy tray desktop & systemd service
cp "$REPO_DIR/src/tray/aod-tray.desktop" "$STAGE_DIR/src/tray/"
cp "$REPO_DIR/src/tray/aod-tray.service" "$STAGE_DIR/src/tray/"

# Copy settings QML, config, and desktop file
cp "$REPO_DIR/src/settings/aod-config.qml" "$STAGE_DIR/src/settings/"
cp "$REPO_DIR/src/settings/default-config.json" "$STAGE_DIR/src/settings/"
cp "$REPO_DIR/src/settings/aod-settings.desktop" "$STAGE_DIR/src/settings/"
cp -r "$REPO_DIR/src/settings/components/." "$STAGE_DIR/src/settings/components/"

# Copy lockscreen QML and patcher
cp "$REPO_DIR/src/lockscreen/AodOverlay.qml.inc" "$STAGE_DIR/src/lockscreen/"
cp "$REPO_DIR/src/lockscreen/patch-lockscreen.awk" "$STAGE_DIR/src/lockscreen/"
install -m 755 "$REPO_DIR/src/lockscreen/patch-lockscreen.sh" "$STAGE_DIR/src/lockscreen/patch-lockscreen.sh"
install -m 755 "$REPO_DIR/src/lockscreen/test-lockscreen.sh" "$STAGE_DIR/src/lockscreen/test-lockscreen.sh"
cp "$REPO_DIR/src/lockscreen/custom-aod/AodClockStats.qml" "$STAGE_DIR/src/lockscreen/custom-aod/"
cp "$REPO_DIR/src/lockscreen/custom-aod/AodSync.js" "$STAGE_DIR/src/lockscreen/custom-aod/"
cp -r "$REPO_DIR/src/lockscreen/custom-aod/components/." "$STAGE_DIR/src/lockscreen/custom-aod/components/"

# Copy assets
cp -r "$REPO_DIR/assets/." "$STAGE_DIR/assets/"

# Copy extensions QML & metadata
cp "$REPO_DIR/src/extensions/io.github.aod4kde.notifications/metadata.json" "$STAGE_DIR/src/extensions/io.github.aod4kde.notifications/"
cp "$REPO_DIR/src/extensions/io.github.aod4kde.notifications/LockscreenWidget.qml" "$STAGE_DIR/src/extensions/io.github.aod4kde.notifications/"

cp "$REPO_DIR/src/extensions/io.github.aod4kde.sensors/metadata.json" "$STAGE_DIR/src/extensions/io.github.aod4kde.sensors/"
cp "$REPO_DIR/src/extensions/io.github.aod4kde.sensors/LockscreenWidget.qml" "$STAGE_DIR/src/extensions/io.github.aod4kde.sensors/"
cp "$REPO_DIR/src/extensions/io.github.aod4kde.sensors/SettingsWidget.qml" "$STAGE_DIR/src/extensions/io.github.aod4kde.sensors/"
cp "$REPO_DIR/src/extensions/io.github.aod4kde.sensors/SensorPickerPopup.qml" "$STAGE_DIR/src/extensions/io.github.aod4kde.sensors/"
if [ -d "$REPO_DIR/src/extensions/io.github.aod4kde.sensors/locale" ]; then
    cp -r "$REPO_DIR/src/extensions/io.github.aod4kde.sensors/locale" "$STAGE_DIR/src/extensions/io.github.aod4kde.sensors/"
fi

# Copy compiled core .mo files
for MO_FILE in "$REPO_DIR/po"/*/LC_MESSAGES/aod4kde.mo; do
    [ -f "$MO_FILE" ] || continue
    LANG_CODE="$(basename "$(dirname "$(dirname "$MO_FILE")")")"
    mkdir -p "$STAGE_DIR/po/$LANG_CODE/LC_MESSAGES"
    cp "$MO_FILE" "$STAGE_DIR/po/$LANG_CODE/LC_MESSAGES/aod4kde.mo"
done

# 3. Create compressed tarball
echo "==> 3/3 Creating archive $DIST_DIR/$ARCHIVE_NAME..."
tar -czf "$DIST_DIR/$ARCHIVE_NAME" -C "$DIST_DIR" aod4kde
rm -rf "$STAGE_DIR"

echo "[OK] Pre-built release archive created: $DIST_DIR/$ARCHIVE_NAME"

