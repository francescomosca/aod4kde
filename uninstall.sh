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

LOCKSCREEN_SYS="/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen"

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}ERROR: Do not run this script with sudo/root!${NC}"
    echo "Run it as a regular user: ./uninstall.sh"
    echo "(You will be prompted for sudo password automatically when needed)."
    exit 1
fi

echo -e "${CYAN}${BOLD}==========================================${NC}"
echo -e "${CYAN}${BOLD}   AOD4KDE Uninstallation                ${NC}"
echo -e "${CYAN}${BOLD}==========================================${NC}"
echo -e "${YELLOW}Note: sudo privileges are required to restore the system lockscreen.${NC}"
sudo -v

echo -e "${CYAN}==> Stopping and removing aod-tray service...${NC}"
systemctl --user disable --now aod-tray.service 2>/dev/null || true
killall aod-tray 2>/dev/null || true
killall aod-settings 2>/dev/null || true

echo -e "${CYAN}==> Removing user files and desktop entries...${NC}"
rm -f "$HOME/.local/share/applications/aod-settings.desktop"
rm -f "$HOME/.config/autostart/aod-tray.desktop"
rm -f "$HOME/.config/systemd/user/aod-tray.service"
systemctl --user daemon-reload 2>/dev/null || true
rm -f "$HOME/.local/bin/aod-settings"
rm -f "$HOME/.local/bin/aod-tray"
rm -rf "$HOME/.local/lib/aod4kde"
rm -rf "$HOME/.local/share/aod4kde"
rm -f "$HOME/.local/share/locale/"*/LC_MESSAGES/aod4kde.mo
rm -f "$HOME/.local/share/locale/"*/LC_MESSAGES/io.github.aod4kde.*.mo
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo -e "${CYAN}==> Removing system hooks and restoring original lockscreen...${NC}"
sudo systemctl disable --now aod4kde-lockscreen.path 2>/dev/null || true
sudo rm -f /etc/systemd/system/aod4kde-lockscreen.path /etc/systemd/system/aod4kde-lockscreen.service
sudo systemctl daemon-reload 2>/dev/null || true

sudo rm -f /etc/pacman.d/hooks/99-aod4kde.hook
sudo rm -f /etc/apt/apt.conf.d/99-aod4kde
sudo rm -rf /usr/share/aod4kde
sudo rm -rf /usr/local/lib/aod4kde
sudo rm -f /usr/share/locale/*/LC_MESSAGES/aod4kde.mo
sudo rm -f /usr/share/locale/*/LC_MESSAGES/io.github.aod4kde.*.mo

if [ -f "$LOCKSCREEN_SYS/LockScreenUi.qml.stock_backup" ]; then
    sudo mv -f "$LOCKSCREEN_SYS/LockScreenUi.qml.stock_backup" "$LOCKSCREEN_SYS/LockScreenUi.qml"
    echo -e "${GREEN}    Original LockScreenUi.qml restored from backup.${NC}"
fi

sudo rm -rf "$LOCKSCREEN_SYS/custom-aod"

echo -e "${GREEN}${BOLD}==========================================${NC}"
echo -e "${GREEN}${BOLD}   UNINSTALLATION COMPLETED!              ${NC}"
echo -e "${GREEN}${BOLD}==========================================${NC}"
