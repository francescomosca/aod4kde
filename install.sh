#!/usr/bin/env bash
set -e

# Terminal colors (if stdout is a terminal)
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

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCKSCREEN_SYS="/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen"
SHARE_LOCKSCREEN="/usr/share/aod4kde/lockscreen"
PATCH_BIN="/usr/local/lib/aod4kde/patch-lockscreen.sh"
TEST_BIN="/usr/local/lib/aod4kde/test-lockscreen.sh"

FORCE_BUILD=0
if [ "${1:-}" = "--build" ]; then
    FORCE_BUILD=1
fi

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}ERROR: Do not run this script with sudo/root!${NC}"
    echo "Run it as a regular user: ./install.sh"
    echo "(You will be prompted for sudo password automatically when needed)."
    exit 1
fi

# Verify KDE Plasma 6 is installed
check_plasma6() {
    local has_plasma6=0
    if command -v plasmashell >/dev/null 2>&1; then
        local ver
        ver="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
        local major="${ver%%.*}"
        if [ -n "$major" ] && [ "$major" -ge 6 ] 2>/dev/null; then
            has_plasma6=1
        elif [ -n "$major" ] && [ "$major" -lt 6 ] 2>/dev/null; then
            echo -e "${RED}ERROR: Detected KDE Plasma $ver, but KDE Plasma >= 6 is required.${NC}"
            exit 1
        fi
    fi

    if [ "$has_plasma6" -eq 0 ]; then
        if [ -d "$LOCKSCREEN_SYS" ] && \
           { command -v kreadconfig6 >/dev/null 2>&1 || command -v kcmshell6 >/dev/null 2>&1; }; then
            has_plasma6=1
        fi
    fi

    if [ "$has_plasma6" -eq 0 ]; then
        echo -e "${RED}ERROR: KDE Plasma 6 not detected on this system.${NC}"
        echo "AOD4KDE requires KDE Plasma >= 6."
        exit 1
    fi
}

check_plasma6

# Check if all runtime dependencies are present on disk; install missing ones automatically if needed
ensure_runtime_deps() {
    local missing_runtime=0

    for cmd in killall update-desktop-database xdg-open ksystemstats; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_runtime=1
            break
        fi
    done

    if [ "$missing_runtime" -eq 0 ]; then
        if ! compgen -G "/usr/lib*/libQt6Svg.so.6*" >/dev/null 2>&1 && \
           ! compgen -G "/usr/lib*/*/libQt6Svg.so.6*" >/dev/null 2>&1; then
            missing_runtime=1
        fi
    fi

    if [ "$missing_runtime" -eq 0 ]; then
        for mod in QtQuick/Controls org/kde/kirigami org/kde/ki18n org/kde/plasma/plasma5support org/kde/ksysguard/sensors; do
            if ! compgen -G "/usr/lib*/qt6/qml/$mod" >/dev/null 2>&1 && \
               ! compgen -G "/usr/lib*/*/qt6/qml/$mod" >/dev/null 2>&1; then
                missing_runtime=1
                break
            fi
        done
    fi

    if [ "$missing_runtime" -eq 0 ]; then
        return 0
    fi

    echo -e "${CYAN}==> Installing missing runtime dependencies...${NC}"
    if command -v pacman >/dev/null 2>&1; then
        local pacman_pkgs=(
            psmisc
            desktop-file-utils
            xdg-utils
            qt6-base
            qt6-svg
            qt6-declarative
            ki18n
            kirigami
            plasma5support
            libksysguard
            ksystemstats
        )
        local missing_pkgs=()
        while IFS= read -r pkg; do
            [ -n "$pkg" ] && missing_pkgs+=("$pkg")
        done < <(pacman -T "${pacman_pkgs[@]}" 2>/dev/null || true)
        if [ "${#missing_pkgs[@]}" -gt 0 ]; then
            sudo pacman -S --needed "${missing_pkgs[@]}"
        fi
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y \
            psmisc \
            desktop-file-utils \
            xdg-utils \
            libqt6svg6 \
            qml6-module-qtquick \
            qml6-module-qtquick-controls \
            qml6-module-qtquick-layouts \
            qml6-module-qtquick-window \
            qml6-module-org-kde-kirigami \
            qml6-module-org-kde-ki18n \
            qml6-module-org-kde-plasma-plasma5support \
            qml6-module-org-kde-ksysguard \
            ksystemstats
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y \
            psmisc \
            desktop-file-utils \
            xdg-utils \
            qt6-qtbase \
            qt6-qtsvg \
            qt6-qtdeclarative \
            kf6-ki18n \
            kf6-kirigami \
            plasma5support \
            libksysguard \
            ksystemstats
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y \
            psmisc \
            desktop-file-utils \
            xdg-utils \
            kirigami6 \
            plasma5support6 \
            libksysguard6 \
            ksystemstats6
    else
        echo -e "${YELLOW}WARNING: Some runtime dependencies may be missing and package manager is unsupported.${NC}"
    fi
}

echo -e "${CYAN}${BOLD}==========================================${NC}"
echo -e "${CYAN}${BOLD}   AOD4KDE Installation                 ${NC}"
echo -e "${CYAN}${BOLD}==========================================${NC}"
echo -e "${YELLOW}Note: sudo privileges are required to patch the system lockscreen.${NC}"
sudo -v

ensure_runtime_deps

# Ensure user directories in ~/.local belong to the actual user (and not root)
sudo chown -R "$USER:$USER" "$HOME/.local/share/aod4kde" "$HOME/.local/lib/aod4kde" 2>/dev/null || true

# 1. Stop aod-tray and build if needed (or use pre-built binaries)
killall aod-tray 2>/dev/null || true

IS_PREBUILT=0
if [ "$FORCE_BUILD" -eq 0 ] && [ -f "$REPO_DIR/.prebuilt" ] && \
   [ -x "$REPO_DIR/src/tray/aod-tray" ] && \
   [ -x "$REPO_DIR/src/helper/aod-helper" ] && \
   [ -x "$REPO_DIR/src/settings/aod-settings" ] && \
   [ -x "$REPO_DIR/src/extensions/io.github.aod4kde.notifications/bin/aod-ext-notifications" ] && \
   [ -x "$REPO_DIR/src/extensions/io.github.aod4kde.sensors/bin/aod-ext-sensors" ]; then
    IS_PREBUILT=1
fi

if [ "$IS_PREBUILT" -eq 1 ]; then
    echo -e "${CYAN}==> 1/5 Using pre-built binaries and translations (skipping compilation)...${NC}"
else
    echo -e "${CYAN}==> 1/5 Building C++ binaries & translations (Developer / Source mode)...${NC}"
    for cmd in g++ make pkg-config xgettext msgmerge msgfmt; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${RED}ERROR: Build tool '$cmd' is missing.${NC}"
            echo "Run ./install-deps.sh first to install build dependencies, or download a pre-built release tarball."
            exit 1
        fi
    done
    make -C "$REPO_DIR/src/tray"
    make -C "$REPO_DIR/src/helper"
    make -C "$REPO_DIR/src/settings"
    make -C "$REPO_DIR/src/extensions/io.github.aod4kde.notifications/daemon"
    make -C "$REPO_DIR/src/extensions/io.github.aod4kde.sensors/daemon"
    bash "$REPO_DIR/tools/update-translations.sh"
fi

# 2. Patch and test system lockscreen FIRST (abort cleanly before installing anything if incompatible)
echo -e "${CYAN}==> 2/5 Patching and testing system lockscreen...${NC}"
HAD_SYSTEM_INSTALL=0
if [ -d "/usr/share/aod4kde" ]; then
    HAD_SYSTEM_INSTALL=1
fi

sudo systemctl stop aod4kde-lockscreen.path 2>/dev/null || true

if ! sudo "$REPO_DIR/src/lockscreen/patch-lockscreen.sh"; then
    if [ "$HAD_SYSTEM_INSTALL" -eq 0 ]; then
        sudo rm -rf /usr/share/aod4kde
    fi
    echo -e "${RED}Installation aborted.${NC}" >&2
    exit 1
fi

# 3. Install system files and automatic update hooks (requires sudo)
echo -e "${CYAN}==> 3/5 Installing system files and update hooks...${NC}"
sudo rm -rf "$SHARE_LOCKSCREEN"
sudo mkdir -p "$SHARE_LOCKSCREEN/custom-aod/components" "$SHARE_LOCKSCREEN/custom-aod/assets" "/usr/share/aod4kde/extensions" "/usr/local/lib/aod4kde"
sudo cp "$REPO_DIR/src/lockscreen/AodOverlay.qml.inc" "$SHARE_LOCKSCREEN/"
sudo cp "$REPO_DIR/src/lockscreen/patch-lockscreen.awk" "$SHARE_LOCKSCREEN/"
sudo install -m 755 "$REPO_DIR/src/lockscreen/test-lockscreen.sh" "$SHARE_LOCKSCREEN/test-lockscreen.sh"
sudo cp "$REPO_DIR/src/lockscreen/custom-aod/AodClockStats.qml" "$SHARE_LOCKSCREEN/custom-aod/"
sudo cp "$REPO_DIR/src/lockscreen/custom-aod/AodSync.js" "$SHARE_LOCKSCREEN/custom-aod/"
sudo cp -r "$REPO_DIR/src/lockscreen/custom-aod/components/." "$SHARE_LOCKSCREEN/custom-aod/components/"
sudo cp -r "$REPO_DIR/assets/." "$SHARE_LOCKSCREEN/custom-aod/assets/"
sudo cp -rf "$SHARE_LOCKSCREEN/custom-aod/." "$LOCKSCREEN_SYS/custom-aod/"
sudo cp -rf "$REPO_DIR/src/extensions/io.github.aod4kde.notifications" "/usr/share/aod4kde/extensions/"
sudo cp -rf "$REPO_DIR/src/extensions/io.github.aod4kde.sensors" "/usr/share/aod4kde/extensions/"
sudo install -m 755 "$REPO_DIR/src/helper/aod-helper" "/usr/local/lib/aod4kde/aod-helper"

# Install system locale catalogs (core + extensions)
for MO_FILE in "$REPO_DIR/po"/*/LC_MESSAGES/aod4kde.mo; do
    [ -f "$MO_FILE" ] || continue
    LANG_CODE="$(basename "$(dirname "$(dirname "$MO_FILE")")")"
    sudo mkdir -p "/usr/share/locale/$LANG_CODE/LC_MESSAGES"
    sudo install -m 644 "$MO_FILE" "/usr/share/locale/$LANG_CODE/LC_MESSAGES/aod4kde.mo"
done
for EXT_MO in "$REPO_DIR/src/extensions"/*/locale/*/LC_MESSAGES/*.mo; do
    [ -f "$EXT_MO" ] || continue
    LANG_CODE="$(basename "$(dirname "$(dirname "$EXT_MO")")")"
    MO_NAME="$(basename "$EXT_MO")"
    sudo mkdir -p "/usr/share/locale/$LANG_CODE/LC_MESSAGES"
    sudo install -m 644 "$EXT_MO" "/usr/share/locale/$LANG_CODE/LC_MESSAGES/$MO_NAME"
done

sudo mkdir -p "$(dirname "$PATCH_BIN")"
sudo install -m 755 "$REPO_DIR/src/lockscreen/patch-lockscreen.sh" "$PATCH_BIN"
sudo install -m 755 "$REPO_DIR/src/lockscreen/test-lockscreen.sh" "$TEST_BIN"

# Install automatic update hooks based on package manager / systemd present on the OS
# a) Arch Linux / derivatives (Pacman ALPM hook)
if [ -d /etc/pacman.d ] || command -v pacman >/dev/null 2>&1; then
    sudo mkdir -p /etc/pacman.d/hooks
    sudo tee /etc/pacman.d/hooks/99-aod4kde.hook >/dev/null <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Type = Path
Target = usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/*

[Action]
Description = Re-applying AOD4KDE patch to Plasma lockscreen...
When = PostTransaction
Exec = $PATCH_BIN
EOF
    echo -e "${GREEN}    Pacman hook installed in /etc/pacman.d/hooks/99-aod4kde.hook${NC}"
fi

# b) Debian / Ubuntu / KDE Neon / Mint (APT hook)
if [ -d /etc/apt/apt.conf.d ]; then
    sudo tee /etc/apt/apt.conf.d/99-aod4kde >/dev/null <<EOF
DPkg::Post-Invoke { "if [ -x $PATCH_BIN ]; then $PATCH_BIN || true; fi"; };
EOF
    echo -e "${GREEN}    APT hook installed in /etc/apt/apt.conf.d/99-aod4kde${NC}"
fi

# c) Any Linux distribution with systemd (Fedora, openSUSE, Arch, Debian, etc.):
#    systemd.path monitors changes to LockScreenUi.qml (e.g. after package update) and reapplies patch if needed
if [ -d /etc/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
    sudo tee /etc/systemd/system/aod4kde-lockscreen.service >/dev/null <<EOF
[Unit]
Description=Apply AOD4KDE Lockscreen Patch

[Service]
Type=oneshot
ExecCondition=/bin/sh -c '! grep -q "id: aodClockStats" "$LOCKSCREEN_SYS/LockScreenUi.qml"'
ExecStart=$PATCH_BIN
EOF
    sudo tee /etc/systemd/system/aod4kde-lockscreen.path >/dev/null <<EOF
[Unit]
Description=Monitor KDE LockScreenUi.qml for package updates (AOD4KDE)

[Path]
PathChanged=$LOCKSCREEN_SYS/LockScreenUi.qml
Unit=aod4kde-lockscreen.service

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl enable --now aod4kde-lockscreen.path 2>/dev/null || true
    echo -e "${GREEN}    systemd watcher installed (aod4kde-lockscreen.path)${NC}"
fi

# 4. Setup user application files, configuration, and desktop entries
echo -e "${CYAN}==> 4/5 Setting up user files and desktop entries ($HOME/.local/share/aod4kde)...${NC}"
mkdir -p "$HOME/.local/share/aod4kde/extensions"
mkdir -p "$HOME/.local/share/aod4kde/components"
mkdir -p "$HOME/.local/share/aod4kde/assets"
mkdir -p "$HOME/.local/lib/aod4kde"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.config"

# Copy runtime QML, config, and asset files
cp "$REPO_DIR/src/settings/aod-config.qml" "$HOME/.local/share/aod4kde/"
cp "$REPO_DIR/src/settings/default-config.json" "$HOME/.local/share/aod4kde/"
cp "$REPO_DIR/src/settings/aod-settings.desktop" "$HOME/.local/share/aod4kde/"
cp -r "$REPO_DIR/src/settings/components/." "$HOME/.local/share/aod4kde/components/"
cp -r "$REPO_DIR/assets/." "$HOME/.local/share/aod4kde/assets/"

install -m 755 "$REPO_DIR/src/tray/aod-tray" "$HOME/.local/bin/aod-tray"
install -m 755 "$REPO_DIR/src/settings/aod-settings" "$HOME/.local/bin/aod-settings"
install -m 755 "$REPO_DIR/src/helper/aod-helper" "$HOME/.local/lib/aod4kde/aod-helper"

# Install user locale catalogs (core + extensions)
for MO_FILE in "$REPO_DIR/po"/*/LC_MESSAGES/aod4kde.mo; do
    [ -f "$MO_FILE" ] || continue
    LANG_CODE="$(basename "$(dirname "$(dirname "$MO_FILE")")")"
    mkdir -p "$HOME/.local/share/locale/$LANG_CODE/LC_MESSAGES"
    install -m 644 "$MO_FILE" "$HOME/.local/share/locale/$LANG_CODE/LC_MESSAGES/aod4kde.mo"
done
for EXT_MO in "$REPO_DIR/src/extensions"/*/locale/*/LC_MESSAGES/*.mo; do
    [ -f "$EXT_MO" ] || continue
    LANG_CODE="$(basename "$(dirname "$(dirname "$EXT_MO")")")"
    MO_NAME="$(basename "$EXT_MO")"
    mkdir -p "$HOME/.local/share/locale/$LANG_CODE/LC_MESSAGES"
    install -m 644 "$EXT_MO" "$HOME/.local/share/locale/$LANG_CODE/LC_MESSAGES/$MO_NAME"
done

if [ ! -f "$HOME/.config/aod4kde.json" ]; then
    cp "$REPO_DIR/src/settings/default-config.json" "$HOME/.config/aod4kde.json"
    echo -e "${GREEN}    Created $HOME/.config/aod4kde.json${NC}"
else
    echo "    $HOME/.config/aod4kde.json already exists."
fi

mkdir -p "$HOME/.local/share/applications"

sed -e "s|^Exec=aod-settings|Exec=$HOME/.local/bin/aod-settings|" "$REPO_DIR/src/settings/aod-settings.desktop" > "$HOME/.local/share/applications/aod-settings.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
echo "    aod-settings.desktop -> $HOME/.local/share/applications/"

# Prevent duplicate startup: use systemd user service if available, otherwise fallback to ~/.config/autostart
if command -v systemctl >/dev/null 2>&1 && systemctl --user list-units >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/systemd/user"
    cp "$REPO_DIR/src/tray/aod-tray.service" "$HOME/.config/systemd/user/aod-tray.service"
    rm -f "$HOME/.config/autostart/aod-tray.desktop"
    echo "    aod-tray.service     -> $HOME/.config/systemd/user/ (managed via systemd user)"
else
    mkdir -p "$HOME/.config/autostart"
    sed -e "s|^Exec=aod-tray|Exec=$HOME/.local/bin/aod-tray|" "$REPO_DIR/src/tray/aod-tray.desktop" > "$HOME/.config/autostart/aod-tray.desktop"
    echo "    aod-tray.desktop     -> $HOME/.config/autostart/ (fallback autostart XDG)"
fi

# 5. Start or restart tray
echo -e "${CYAN}==> 5/5 Starting / Restarting aod-tray...${NC}"
if command -v systemctl >/dev/null 2>&1 && systemctl --user list-units >/dev/null 2>&1; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now aod-tray.service 2>/dev/null || true
    systemctl --user restart aod-tray.service 2>/dev/null || true
else
    killall aod-tray 2>/dev/null || true
    "$HOME/.local/bin/aod-tray" >/dev/null 2>&1 &
fi

echo ""
echo -e "${GREEN}${BOLD}==========================================${NC}"
echo -e "${GREEN}${BOLD}   INSTALLATION COMPLETED SUCCESSFULLY!   ${NC}"
echo -e "${GREEN}${BOLD}==========================================${NC}"
echo -e " - AOD4KDE active on lock screen (${BOLD}Meta + L${NC})"
echo " - Icon present in System Tray"
echo " - 'AOD4KDE Settings' available in app menu"
echo -e "${GREEN}${BOLD}==========================================${NC}"
