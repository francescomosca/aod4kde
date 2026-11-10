#!/usr/bin/env bash
set -e

LOCKSCREEN_SYS="/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen"
UI_FILE="$LOCKSCREEN_SYS/LockScreenUi.qml"

if [ ! -f "$UI_FILE" ]; then
    echo "ERROR: $UI_FILE not found." >&2
    exit 1
fi

# 1. Structural check: ensure all expected patch sections were injected into LockScreenUi.qml
#    (e.g. if a KDE update removes or renames the Clock block, AWK won't inject all components)
MISSING_MARKERS=0
if ! grep -q 'import "custom-aod"' "$UI_FILE"; then
    echo "ERROR: Missing 'import \"custom-aod\"' in patched LockScreenUi.qml." >&2
    MISSING_MARKERS=1
fi
if ! grep -q "id: aodManager" "$UI_FILE"; then
    echo "ERROR: Missing 'id: aodManager' in patched LockScreenUi.qml (upstream Clock block may have changed)." >&2
    MISSING_MARKERS=1
fi
if ! grep -q "id: aodClockStats" "$UI_FILE"; then
    echo "ERROR: Missing 'id: aodClockStats' in patched LockScreenUi.qml." >&2
    MISSING_MARKERS=1
fi
if ! grep -q "opacity: lockScreenRoot.uiVisible ? 1 : 0" "$UI_FILE"; then
    echo "ERROR: Stock clock visibility binding was not patched in LockScreenUi.qml (upstream 'id: clock' may have changed)." >&2
    MISSING_MARKERS=1
fi

if [ "$MISSING_MARKERS" -ne 0 ]; then
    exit 1
fi

# 2. Headless greeter dry-run: locate kscreenlocker_greet and simulate loading the lockscreen offscreen
GREETER_BIN=""
if command -v kscreenlocker_greet >/dev/null 2>&1; then
    GREETER_BIN="$(command -v kscreenlocker_greet)"
else
    for p in /usr/lib/kscreenlocker_greet /usr/libexec/kscreenlocker_greet /usr/lib/*/libexec/kscreenlocker_greet /usr/lib64/libexec/kscreenlocker_greet; do
        if [ -x "$p" ]; then
            GREETER_BIN="$p"
            break
        fi
    done
    if [ -z "$GREETER_BIN" ]; then
        GREETER_BIN="$(find /usr/lib* /usr/libexec -name kscreenlocker_greet -type f -executable 2>/dev/null | head -n 1)"
    fi
fi

if [ -z "$GREETER_BIN" ] || [ ! -x "$GREETER_BIN" ]; then
    echo "WARNING: kscreenlocker_greet not found; skipping headless QML runtime test." >&2
    exit 0
fi

TMP_DIR="$(mktemp -d)"
chmod 700 "$TMP_DIR"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

GREETER_OUT="$(env -i PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/bin" \
    HOME="$TMP_DIR" \
    XDG_CACHE_HOME="$TMP_DIR/cache" \
    XDG_RUNTIME_DIR="$TMP_DIR" \
    QML_DISABLE_DISK_CACHE=1 \
    QT_LOGGING_RULES="kscreenlocker_greet*=true;*.warning=true" \
    timeout 2s "$GREETER_BIN" --testing --shell org.kde.plasma.desktop -platform offscreen 2>&1 || true)"

if echo "$GREETER_OUT" | grep -qiE "falling back to built-in locker|fallbacktheme|Failed to load lockscreen QML|Failed to load the fallback lockscreen QML|Lockscreen QML outdated|Type LockScreenUi unavailable|Type AodClockStats unavailable"; then
    echo "ERROR: kscreenlocker_greet failed to load patched lockscreen QML (fallbacktheme triggered)." >&2
    echo "--- QML / Greeter error details ---" >&2
    echo "$GREETER_OUT" | grep -iE "kscreenlocker_greet:|file:///|Error|unavailable|fallback" >&2 || true
    echo "-----------------------------------" >&2
    exit 1
fi

if ! echo "$GREETER_OUT" | grep -q "AOD_SYNC: registerScreen"; then
    echo "ERROR: AOD overlay (aodManager) did not initialize during kscreenlocker_greet headless test." >&2
    echo "--- QML / Greeter output ---" >&2
    echo "$GREETER_OUT" | grep -iE "kscreenlocker_greet:|file:///|qml:|Error" >&2 || true
    echo "----------------------------" >&2
    exit 1
fi

exit 0

