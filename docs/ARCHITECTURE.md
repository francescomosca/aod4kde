
# AOD4KDE Architecture

AOD4KDE is composed of four modular components that communicate seamlessly:
1. **`aod-tray`** (Qt6): Background application managing the system tray menu, auto-start, configuration synchronization, and supervising extension daemons.
2. **`aod-settings`** (Kirigami): Settings manager allowing appearance tuning, clock selection, display assignment, and extension configuration.
3. **`aod-helper`** (Qt6): Lightweight C++ CLI helper responsible for reading/writing JSON state, managing extensions, and interacting with system paths.
4. **`lockscreen` patch (`custom-aod`)**: QML overlay injected into KDE's lockscreen greeter.

## Folder Tree

```
aod4kde/
├── assets/                # Icons, branding assets, and bundled TTF fonts
├── docs/                  # Developer guides and extension templates
│   ├── custom_extensions/ # Extension docs and starter examples
│   ├── resources/         # Assets used across the documentation
├── packaging/             # Packaging scripts (Arch Linux PKGBUILDs)
├── po/                    # Gettext translation catalogs (.pot, .po)
├── src/
│   ├── common/            # Shared C++ headers
│   ├── extensions/        # Built-in extensions
│   ├── helper/            # aod-helper CLI tool
│   ├── lockscreen/        # QML overlay, AWK patcher, and headless validation tests
│   ├── settings/          # aod-settings GUI
│   └── tray/              # aod-tray daemon and extension supervisor
├── tools/                 # Maintenance, compilation, and localization scripts
├── install-deps.sh        # Dependency installer script
├── install.sh             # Main build and installation script
├── uninstall.sh           # Complete uninstaller and lockscreen restore script
└── LICENSE                # GNU General Public License v2.0 text
```

## Lockscreen Patch & Safety Mechanisms

AOD4KDE injects its overlay into KDE Plasma's lockscreen greeter (`kscreenlocker_greet`) by surgically patching `/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockScreenUi.qml` with an idempotent AWK script. Supporting QML and asset files are placed in a isolated `custom-aod/` subfolder.

### Protection Across System Updates
Whenever your distribution updates `plasma-desktop`, the system package manager overwrites `LockScreenUi.qml`. AOD4KDE installs automatic hooks to detect updates and re-apply the patch transparently:
- **Arch Linux**: Pacman ALPM hook (`/etc/pacman.d/hooks/99-aod4kde.hook`).
- **Debian / Ubuntu / KDE Neon**: APT post-invoke hook (`/etc/apt/apt.conf.d/99-aod4kde`).
- **Universal systemd**: `aod4kde-lockscreen.path` monitors the lockscreen QML file and triggers re-patching immediately on file modification.

### Automated Headless Verification
To ensure system stability, every patch execution runs `test-lockscreen.sh`. This runs `kscreenlocker_greet` in a headless offscreen sandbox (`--testing -platform offscreen`). If the greeter encounters a syntax error or triggers KDE's fallback locker, the script **immediately reverts** `LockScreenUi.qml` from `LockScreenUi.qml.stock_backup`, cleans up the overlay, and leaves the lockscreen safely unpatched.

## Extension System

AOD4KDE features an isolated extension architecture. Extensions can be installed system-wide in `/usr/share/aod4kde/extensions/` or locally in `~/.local/share/aod4kde/extensions/`.

Each extension bundle includes:
- `metadata.json`: Defines ID (reverse-DNS), name, version, icons, and entry points.
- `LockscreenWidget.qml`: The QML widget rendered on the AOD screen. Receives host properties like `uiScale`, `aodVisible`, and `extensionConfig`.
- `SettingsWidget.qml` *(optional)*: Embedded inside the `aod-settings` accordion to provide custom configuration options.
- `daemon/` *(optional)*: An independent background service (compiled C++, Python script, Bash, Rust, etc.) supervised directly by `aod-tray`.

Data exchange between background daemons and QML widgets is decoupled via atomic JSON files stored in `$XDG_RUNTIME_DIR/`.

For complete implementation details and boilerplates, refer to the [Extension Development Guide](./custom_extensions/README.md).