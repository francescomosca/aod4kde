#!/usr/bin/env bash
set -e

REPO="francescomosca/aod4kde"
TAR_URL="https://github.com/$REPO/releases/latest/download/aod4kde-linux-x86_64.tar.gz"
ARCH_PKG_URL="https://github.com/$REPO/releases/latest/download/aod4kde-bin-x86_64.pkg.tar.zst"

if [ -t 1 ]; then
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    CYAN=''
    GREEN=''
    RED=''
    NC=''
fi

echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}   AOD4KDE - One-line Web Installer${NC}"
echo -e "${CYAN}==========================================${NC}"

# Check for root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}ERROR: Please do not run this installer directly as root or with sudo.${NC}"
    echo "Run it as your normal user. Sudo will be requested automatically when needed."
    exit 1
fi

# 1. Arch Linux / derivatives
if [ -f /etc/arch-release ] && command -v pacman >/dev/null 2>&1; then
    echo -e "${CYAN}==> Arch Linux detected. Installing native package via pacman...${NC}"
    sudo pacman -U "$ARCH_PKG_URL"
    echo -e "${GREEN}[OK] AOD4KDE installed successfully!${NC}"
    exit 0
fi

# 2. Generic Linux (Ubuntu, Debian, Fedora, openSUSE, etc.)
echo -e "${CYAN}==> Generic Linux detected. Downloading latest pre-built tarball...${NC}"
TMP_DIR="$(mktemp -d -t aod4kde-install.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! curl -sSLf "$TAR_URL" | tar -xz -C "$TMP_DIR"; then
    echo -e "${RED}ERROR: Failed to download or extract AOD4KDE release archive.${NC}"
    exit 1
fi

echo -e "${CYAN}==> Running installer...${NC}"
"$TMP_DIR/aod4kde/install.sh" "$@"

