#!/usr/bin/env bash
set -e

echo "=========================================="
echo "   AOD4KDE - Dependency Installer"
echo "=========================================="

# 1. Verify KDE Plasma 6 is installed
check_plasma6() {
    local has_plasma6=0

    if command -v plasmashell >/dev/null 2>&1; then
        local ver
        ver="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
        local major="${ver%%.*}"
        if [ -n "$major" ] && [ "$major" -ge 6 ] 2>/dev/null; then
            has_plasma6=1
        elif [ -n "$major" ] && [ "$major" -lt 6 ] 2>/dev/null; then
            echo "ERROR: Detected KDE Plasma $ver, but KDE Plasma >= 6 is required."
            exit 1
        fi
    fi

    # Fallback check if plasmashell cannot connect to display or failed version output
    if [ "$has_plasma6" -eq 0 ]; then
        if [ -d "/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen" ] && \
           { command -v kreadconfig6 >/dev/null 2>&1 || command -v kcmshell6 >/dev/null 2>&1; }; then
            has_plasma6=1
        fi
    fi

    if [ "$has_plasma6" -eq 0 ]; then
        echo "ERROR: KDE Plasma 6 not detected on this system."
        echo "This project requires KDE Plasma >= 6 to run and patch the lockscreen."
        exit 1
    fi

    echo "[OK] KDE Plasma 6 detected."
}

check_plasma6

# 2. Detect Package Manager & Install Dependencies
echo "==> Detecting package manager and installing dependencies..."

if command -v pacman >/dev/null 2>&1; then
    echo "    Detected Arch Linux / Pacman-based distribution"
    PACMAN_PKGS=(
        gcc
        make
        pkgconf
        gettext
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

    # Only install packages that are completely missing locally (pacman -T).
    # Passing already-installed packages (like qt6-base) to 'pacman -S --needed' on a LiveCD
    # or un-updated system with a newer sync DB causes a partial upgrade that breaks KDE's Qt_6_PRIVATE_API!
    MISSING_PKGS=()
    while IFS= read -r pkg; do
        [ -n "$pkg" ] && MISSING_PKGS+=("$pkg")
    done < <(pacman -T "${PACMAN_PKGS[@]}" 2>/dev/null || true)

    if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
        echo "    Installing missing packages: ${MISSING_PKGS[*]}"
        sudo pacman -S --needed "${MISSING_PKGS[@]}"
    else
        echo "    All required Pacman packages are already installed."
    fi

elif command -v apt-get >/dev/null 2>&1; then
    echo "    Detected Debian / Ubuntu / KDE Neon (APT-based distribution)"
    sudo apt-get update
    sudo apt-get install -y \
        build-essential \
        pkg-config \
        gettext \
        psmisc \
        desktop-file-utils \
        xdg-utils \
        qt6-base-dev \
        qt6-base-dev-tools \
        libqt6svg6-dev \
        qt6-declarative-dev \
        qml6-module-qtquick \
        qml6-module-qtquick-controls \
        qml6-module-qtquick-layouts \
        qml6-module-qtquick-window \
        qml6-module-org-kde-kirigami \
        qml6-module-org-kde-ki18n \
        qml6-module-org-kde-plasma-plasma5support \
        qml6-module-org-kde-ksysguard \
        libkf6i18n-dev \
        ksystemstats

elif command -v dnf >/dev/null 2>&1; then
    echo "    Detected Fedora / DNF-based distribution"
    sudo dnf install -y \
        gcc-c++ \
        make \
        pkgconf-pkg-config \
        gettext \
        psmisc \
        desktop-file-utils \
        xdg-utils \
        qt6-qtbase-devel \
        qt6-qtsvg-devel \
        qt6-qtdeclarative-devel \
        kf6-ki18n-devel \
        kf6-kirigami \
        plasma5support \
        libksysguard \
        ksystemstats

elif command -v zypper >/dev/null 2>&1; then
    echo "    Detected openSUSE / Zypper-based distribution"
    sudo zypper install -y \
        gcc-c++ \
        make \
        pkg-config \
        gettext-tools \
        psmisc \
        desktop-file-utils \
        xdg-utils \
        qt6-base-devel \
        qt6-core-devel \
        qt6-gui-devel \
        qt6-widgets-devel \
        qt6-dbus-devel \
        qt6-svg-devel \
        qt6-declarative-devel \
        qt6-qml-devel \
        qt6-quick-devel \
        kf6-ki18n-devel \
        kirigami6 \
        plasma5support6 \
        libksysguard6 \
        ksystemstats6

else
    echo "ERROR: Unsupported package manager."
    echo "Please install the required Qt6 (Core, Gui, Widgets, DBus, Svg, Qml, Quick), KF6::I18n, gettext, and C++ build tools manually."
    exit 1
fi

# 3. Post-install verification
echo ""
echo "==> Verifying build & runtime prerequisites..."
MISSING=0

for cmd in g++ make pkg-config xgettext msgmerge msgfmt killall; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "  [MISSING] Command not found: $cmd"
        MISSING=1
    fi
done

for pc in Qt6Core Qt6Gui Qt6Widgets Qt6DBus Qt6Svg Qt6Qml Qt6Quick; do
    if ! pkg-config --exists "$pc" 2>/dev/null; then
        echo "  [MISSING] pkg-config module not found: $pc"
        MISSING=1
    fi
done

if [ ! -f "/usr/include/KF6/KI18n/klocalizedstring.h" ] && [ ! -f "/usr/local/include/KF6/KI18n/klocalizedstring.h" ]; then
    echo "  [MISSING] KF6::I18n headers not found (/usr/include/KF6/KI18n/klocalizedstring.h)"
    MISSING=1
fi

if [ "$MISSING" -ne 0 ]; then
    echo ""
    echo "WARNING: Some dependencies appear to be missing. Check the errors above."
    exit 1
fi

echo "[OK] All dependencies are installed! You can now run ./install.sh"
