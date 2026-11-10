Core C++ and QML source code for AOD4KDE:

- **`common/`**: Shared C++ headers (JSON configuration management and extension discovery/localization).
- **`extensions/`**: Built-in extensions for AOD4KDE, with their QML widgets, C++ daemons, and translations.
- **`helper/`**: CLI utility (`aod-helper`) used by QML components to read/write configuration and manage extensions.
- **`lockscreen/`**: QML overlay (`AodClockStats.qml`), UI components, and the system lockscreen patcher script.
- **`settings/`**: AOD settings application (`aod-settings` - Kirigami/QML).
- **`tray/`**: System tray application (`aod-tray`) and background daemons.
