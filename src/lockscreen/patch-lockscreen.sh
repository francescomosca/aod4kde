#!/usr/bin/env bash
set -e

# Terminal colors (if stdout/stderr is a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi

LOCKSCREEN_SYS="/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen"
CUSTOM_AOD_SYS="$LOCKSCREEN_SYS/custom-aod"
SHARE_DIR="/usr/share/aod4kde/lockscreen"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$LOCKSCREEN_SYS" ]; then
    exit 0
fi

# 1. Copy fresh AOD files into $LOCKSCREEN_SYS/custom-aod/
rm -rf "$CUSTOM_AOD_SYS"
mkdir -p "$CUSTOM_AOD_SYS"
if [ -d "$SCRIPT_DIR/custom-aod" ]; then
    cp -rf "$SCRIPT_DIR/custom-aod/." "$CUSTOM_AOD_SYS/"
    if [ -d "$SCRIPT_DIR/../../assets" ]; then
        mkdir -p "$CUSTOM_AOD_SYS/assets"
        cp -rf "$SCRIPT_DIR/../../assets/." "$CUSTOM_AOD_SYS/assets/"
    fi
elif [ -d "$SHARE_DIR/custom-aod" ]; then
    cp -rf "$SHARE_DIR/custom-aod/." "$CUSTOM_AOD_SYS/"
fi

# 2. Locate AWK patcher script and QML overlay fragment
AWK_SCRIPT=""
if [ -f "$SCRIPT_DIR/patch-lockscreen.awk" ]; then
    AWK_SCRIPT="$SCRIPT_DIR/patch-lockscreen.awk"
elif [ -f "$SHARE_DIR/patch-lockscreen.awk" ]; then
    AWK_SCRIPT="$SHARE_DIR/patch-lockscreen.awk"
fi

OVERLAY_FILE=""
if [ -f "$SCRIPT_DIR/AodOverlay.qml.inc" ]; then
    OVERLAY_FILE="$SCRIPT_DIR/AodOverlay.qml.inc"
elif [ -f "$SHARE_DIR/AodOverlay.qml.inc" ]; then
    OVERLAY_FILE="$SHARE_DIR/AodOverlay.qml.inc"
fi

if [ -z "$AWK_SCRIPT" ] || [ ! -f "$AWK_SCRIPT" ]; then
    echo -e "${RED}ERROR: patch-lockscreen.awk not found!${NC}" >&2
    exit 1
fi

if [ -z "$OVERLAY_FILE" ] || [ ! -f "$OVERLAY_FILE" ]; then
    echo -e "${RED}ERROR: AodOverlay.qml.inc not found!${NC}" >&2
    exit 1
fi

# 3. Surgical patch on LockScreenUi.qml - always starting from clean KDE stock file
UI_FILE="$LOCKSCREEN_SYS/LockScreenUi.qml"
BACKUP_FILE="$LOCKSCREEN_SYS/LockScreenUi.qml.stock_backup"

if [ ! -f "$UI_FILE" ]; then
    exit 0
fi

is_clean_stock() {
    local f="$1"
    [ -f "$f" ] || return 1
    ! grep -q 'custom-aod' "$f" && \
    ! grep -q 'id: aodManager' "$f" && \
    ! grep -q 'id: aodClockStats' "$f"
}

print_stock_markers() {
    local target="$1"
    local name="$2"
    if [ ! -f "$target" ]; then
        echo -e "${YELLOW}  - $name: file does not exist${NC}" >&2
        return
    fi
    local found=""
    if grep -q 'custom-aod' "$target"; then found="${found:+$found, }'custom-aod'"; fi
    if grep -q 'id: aodManager' "$target"; then found="${found:+$found, }'id: aodManager'"; fi
    if grep -q 'id: aodClockStats' "$target"; then found="${found:+$found, }'id: aodClockStats'"; fi
    if [ -n "$found" ]; then
        echo -e "${YELLOW}  - $name: found unexpected marker(s): $found${NC}" >&2
    else
        echo -e "${GREEN}  - $name: clean (no AOD markers found)${NC}" >&2
    fi
}

# If current system file is clean KDE stock (e.g. first install or freshly updated by distro package manager),
# update stock backup with this clean KDE version!
if is_clean_stock "$UI_FILE"; then
    cp -f "$UI_FILE" "$BACKUP_FILE"
fi

# Apply patch starting from a verified clean stock file (100% idempotent)
if is_clean_stock "$BACKUP_FILE"; then
    SOURCE_FILE="$BACKUP_FILE"
elif is_clean_stock "$UI_FILE"; then
    SOURCE_FILE="$UI_FILE"
else
    echo -e "${RED}ERROR: Neither LockScreenUi.qml nor its backup is a clean stock KDE file!${NC}" >&2
    echo -e "${YELLOW}Detected status:${NC}" >&2
    print_stock_markers "$UI_FILE" "Current LockScreenUi.qml ($UI_FILE)"
    print_stock_markers "$BACKUP_FILE" "Backup file ($BACKUP_FILE)"
    echo -e "${RED}Aborting patch to prevent lockscreen corruption.${NC}" >&2
    exit 1
fi

awk -f "$AWK_SCRIPT" -v overlay_file="$OVERLAY_FILE" "$SOURCE_FILE" > "${UI_FILE}.aod_tmp" && mv -f "${UI_FILE}.aod_tmp" "$UI_FILE"
chmod 644 "$UI_FILE"

# 4. Verify patched lockscreen (structural + headless offscreen greeter test)
TEST_SCRIPT=""
for candidate in "$SCRIPT_DIR/test-lockscreen.sh" "$SHARE_DIR/test-lockscreen.sh" "/usr/local/lib/aod4kde/test-lockscreen.sh" "/usr/lib/aod4kde/test-lockscreen.sh"; do
    if [ -x "$candidate" ]; then
        TEST_SCRIPT="$candidate"
        break
    fi
done

if [ -n "$TEST_SCRIPT" ]; then
    echo -e "${CYAN}    Testing patched lockscreen (headless dry-run)...${NC}"
    if ! "$TEST_SCRIPT"; then
        echo "" >&2
        echo -e "${RED}${BOLD}==========================================${NC}" >&2
        echo -e "${RED}${BOLD}   ERROR: LOCKSCREEN PATCH TEST FAILED!   ${NC}" >&2
        echo -e "${RED}${BOLD}==========================================${NC}" >&2
        echo -e "${RED}The patched lockscreen failed validation (upstream KDE lockscreen QML may have changed).${NC}" >&2
        echo -e "${YELLOW}Restoring original unpatched lockscreen to keep your system safe...${NC}" >&2

        # Disable systemd watcher before restoring stock file to prevent infinite re-patch loops
        if command -v systemctl >/dev/null 2>&1; then
            systemctl disable --now aod4kde-lockscreen.path 2>/dev/null || true
        fi

        if [ -f "$BACKUP_FILE" ]; then
            mv -f "$BACKUP_FILE" "$UI_FILE"
            chmod 644 "$UI_FILE"
            echo -e "${YELLOW}Original LockScreenUi.qml restored from backup.${NC}" >&2
        fi
        rm -rf "$CUSTOM_AOD_SYS"
        mkdir -p "$SHARE_DIR" 2>/dev/null || true
        touch "$SHARE_DIR/.patch_failed" 2>/dev/null || true
        echo -e "${YELLOW}Lockscreen restored to pre-patch state.${NC}" >&2

        # Notify active desktop sessions if triggered in background (e.g. during system update)
        if command -v notify-send >/dev/null 2>&1 && [ "$EUID" -eq 0 ]; then
            for run_dir in /run/user/*; do
                [ -d "$run_dir" ] || continue
                uid="${run_dir##*/}"
                user_name="$(id -nu "$uid" 2>/dev/null || true)"
                if [ -n "$user_name" ] && [ -S "$run_dir/bus" ]; then
                    su "$user_name" -s /bin/sh -c "DBUS_SESSION_BUS_ADDRESS='unix:path=$run_dir/bus' notify-send -u critical -a 'AOD4KDE' 'AOD4KDE Lockscreen Patch Failed' 'The lockscreen patch failed after a system update and was automatically removed to keep your lockscreen safe.'" 2>/dev/null || true
                fi
            done
        fi

        exit 1
    fi
    rm -f "$SHARE_DIR/.patch_failed" 2>/dev/null || true
    echo -e "${GREEN}    Lockscreen test passed (OK).${NC}"
fi
