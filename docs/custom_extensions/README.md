# Extension Development Guide for AOD4KDE (Always-On-Display)

This guide explains how to create, test, and distribute extensions (plugins) for AOD4KDE.

Inside the `examples/` directory, you will find two ready-to-use templates:
1. **`hello_world/`**: minimal QML-only extension, without daemon and without settings panel.
2. **`with_settings_and_daemon/`**: full extension with a C++ background daemon, IPC data exchange, and a configuration widget in `aod-settings`.

For multi-language and translation instructions, see the [Extension Localization Guide](LOCALIZATION.md).

---

## 1. Extension Architecture

Each extension is a self-contained bundle located in a directory named using the `io.github.aod4kde.ext.<name>` reverse-DNS convention (e.g. `io.github.aod4kde.ext.helloworld`), whereas built-in extensions use `io.github.aod4kde.<name>`.

### Where are extensions located?
1. **User / KDE Store (Third-party)**: `~/.local/share/aod4kde/extensions/<id>/`
2. **System (Built-in, root-protected)**: `/usr/share/aod4kde/extensions/<id>/`

> [!NOTE]
> Your primary development path is `~/.local/share/aod4kde/extensions/`. Your extension will automatically be marked as **Community / Third-Party** in the settings interface.

---

## 2. File Structure

```
~/.local/share/aod4kde/extensions/<id>/
├── metadata.json           # Required extension metadata
├── LockscreenWidget.qml    # Widget rendered on the lockscreen (Required)
├── SettingsWidget.qml      # Settings panel in the aod-settings accordion (Optional)
└── daemon/                 # Background daemon / script (Optional)
    ├── Makefile            # Build system to compile into bin/ (Optional)
    └── main.cpp            # C++ daemon source (or Python, Bash script, etc.)
```

---

## 3. `metadata.json` Specification

```json
{
  "id": "io.github.aod4kde.ext.sampledaemon",
  "name": "Sample Daemon & Settings",
  "description": "Complete example with background C++ daemon and settings panel",
  "icon": "utilities-system-monitor",
  "version": "1.0.0",
  "author": "Community",
  "lockscreenQml": "LockscreenWidget.qml",
  "settingsQml": "SettingsWidget.qml",
  "daemon": "bin/aod-ext-example",
  "defaultConfig": {
    "prefix": "System:",
    "color": "#00ffcc"
  }
}
```

### Fields:
| Field | Type | Description |
|---|---|---|
| `id` | String | Unique identifier (reverse-DNS format). |
| `name` | String | Display name shown in the UI. |
| `description` | String | Description of functionality. |
| `icon` | String | Freedesktop/Breeze icon name (e.g. `dialog-information`, `utilities-system-monitor`). |
| `version` | String | SemVer version (e.g. `1.0.0`). |
| `author` | String | Author or maintainer. |
| `lockscreenQml` | String | Relative QML file path of the lockscreen widget (**required**). |
| `settingsQml` | String | QML file path for settings panel (leave empty `""` if not needed). |
| `daemon` | String | Relative path to background executable/script (leave empty `""` if not present). |
| `defaultConfig` | Object | JSON object containing default plugin settings. |

> [!IMPORTANT]
> - By default, every newly installed extension is **disabled**: the user must explicitly enable it from *AOD Settings -> Extensions*.
> - The display order of widgets on the lockscreen is controlled by the user.

---

## 4. `LockscreenWidget.qml` (Lockscreen Widget)

Instantiated dynamically inside a `Loader` on the lockscreen.

### Properties injected by the host:
- `property real uiScale`: AOD UI scale factor (e.g. `1.0` = 100%, `1.5` = 150%). Always use `Math.round(value * uiScale)` for dimensions and margins.
- `property var extensionConfig`: JSON object containing the extension's current configuration.
- `property var aodConfig`: global AOD configuration (read-only).
- `property bool aodVisible`: `true` when the screen is locked and AOD is actively visible. **Use this property to pause timers or D-Bus polling when screen is unlocked or off**.

---

## 5. `SettingsWidget.qml` (Settings Panel)

If specified in `metadata.json`, it is loaded inside the expandable accordion of the extension card in `aod-settings`. If omitted or left `""`, the card does not display expansion arrows.

### Crash Protection:
If `SettingsWidget.qml` encounters syntax or runtime errors, `aod-settings` displays an isolated error banner within the card and continues operating normally.

### Properties and Signals:
- `property var extensionConfig`: configuration object modifiable by the extension.
- `property var appWindow`: reference to the main settings window.
- `signal settingModified()`: **must be emitted** whenever a property in `extensionConfig` is modified, to enable the *Apply* button and allow saving.

### Modals and Popups in Extensions:
If an extension needs to display modals or pickers (e.g. selector dialogs), declare a `QQC2.Popup` inside `SettingsWidget.qml` setting:
```qml
parent: QQC2.Overlay.overlay
```
This positions the popup at the highest window z-index, preventing clipping by layout bounds or scroll views.

---

## 6. Background Daemon (`daemon`)

If your extension specifies the `"daemon"` field, the process is directly supervised by `aod-tray`:
1. **Automatic start**: launched as soon as the extension is enabled by the user (and global AOD is ON).
2. **Automatic stop**: receives `SIGTERM` (and after a 500ms grace period `SIGKILL` if it hasn't exited) as soon as the extension is disabled or AOD is turned off.
3. **Auto-restart**: if the daemon crashes unexpectedly while the extension is enabled, `aod-tray` restarts it after 2 seconds.

### Supported Languages and Execution:
The system is language-agnostic. You can write your daemon in **C++, Python, Bash, Rust, Go**, or any runtime:
- **Compiled binaries (C++, Rust, Go)**: point directly to the compiled binary (e.g. `"daemon": "bin/aod-ext-example"`). The template `with_settings_and_daemon/daemon/Makefile` provides a minimal `Qt6Core` build example.
- **Interpreted scripts (Python, Bash, etc.)**: include a shebang at the top (e.g. `#!/usr/bin/env python3`), set executable permissions (`chmod +x daemon/your_daemon.py`), and reference it in `metadata.json` (`"daemon": "daemon/your_daemon.py"`).
- **Termination handling (`SIGTERM`)**: always handle `SIGTERM` (e.g. `std::signal(SIGTERM, ...)` in C++, `signal.signal(signal.SIGTERM, ...)` in Python, or `trap` in Bash) to clean up resources and temporary files before the 500ms grace period expires.

### Data Exchange with the QML Widget:
The most efficient and decoupled approach is writing a compact JSON file to RAM in `$XDG_RUNTIME_DIR/<plugin-name>.json` (using atomic writes like `QSaveFile` or atomic `mv`). The QML widget reads it via a timer and `P5Support.DataSource` with `cat`.

### Root Permission Handling (Polkit):
The daemon runs under the current user's privileges. If privileged data is required:
- **Polkit (`pkexec`)**: invoke a dedicated helper via `pkexec /path/to/helper`.
- **Udev / Polkit rules**: install rules in `/etc/udev/rules.d/` or `/etc/polkit-1/rules.d/` to grant non-root device access.
- **System D-Bus**: query existing system services exposed on the system bus (`org.freedesktop.UPower`, `org.freedesktop.login1`, etc.).

---

## 7. How to Test the Included Templates

You can immediately test either example by copying its directory into the user extensions path:

### Testing Example 1: Minimal Hello World (No daemon, no settings)
```bash
cp -r docs/custom_extensions/examples/hello_world ~/.local/share/aod4kde/extensions/io.github.aod4kde.ext.helloworld
```

### Testing Example 2: Complete (With C++ daemon and settings)
```bash
# 1. Build the sample daemon
make -C docs/custom_extensions/examples/with_settings_and_daemon/daemon

# 2. Copy folder to user extensions directory
cp -r docs/custom_extensions/examples/with_settings_and_daemon ~/.local/share/aod4kde/extensions/io.github.aod4kde.ext.sampledaemon
```

### Enabling:
1. Open AOD settings with `aod-settings`.
2. Go to the **Extensions** tab: the new extension will appear in the list.
3. Toggle the checkbox to enable it.
4. Lock the screen (`Super + L` or KDE shortcut) to verify rendering on the Always-On display.
