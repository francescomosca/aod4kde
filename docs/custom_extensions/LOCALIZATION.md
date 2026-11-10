# Third-Party Extension Localization Guide

AOD4KDE provides full localization support for third-party extensions. Extensions can translate their metadata (`metadata.json`), configuration UI (`SettingsWidget.qml`), and lockscreen display (`LockscreenWidget.qml`).

---

## 1. Directory Structure

A fully localized extension contains a `locale/` subdirectory with compiled `.mo` files (and optionally `.po` sources):

```
io.github.aod4kde.ext.myextension/
├── metadata.json
├── LockscreenWidget.qml
├── SettingsWidget.qml
├── daemon/ (optional)
├── locale/ (auto-generated)
│   ├── it/
│   │   └── LC_MESSAGES/
│   │       └── io.github.aod4kde.ext.myext.mo
│   └── de/
│       └── LC_MESSAGES/
│           └── io.github.aod4kde.ext.myext.mo
└── po/ (optional for development)
    ├── io.github.aod4kde.ext.myext.pot
    └── it.po
```

---

## 2. Localizing Metadata (`metadata.json`)

The extension's name and description can be localized directly in `metadata.json` using KDE/XDG language keys (`name[<lang>]`, `description[<lang>]`).
Specify `translationDomain` matching your domain or catalog name (default is the extension `id`):

```json
{
  "id": "io.github.aod4kde.ext.myext",
  "name": "My Extension",
  "name[it]": "La Mia Estensione",
  "description": "Displays custom information on lockscreen",
  "description[it]": "Mostra informazioni personalizzate sullo schermo bloccato",
  "translationDomain": "io.github.aod4kde.ext.myext",
  "icon": "preferences-plugin",
  "version": "1.0.0",
  "author": "Developer Name",
  "lockscreenQml": "LockscreenWidget.qml",
  "settingsQml": "SettingsWidget.qml"
}
```

AOD4KDE's extension scanner automatically inspects the user's active system locale (`QLocale::system().name()`) and resolves `name[it]` and `description[it]` automatically.

---

## 3. Localizing QML Widgets (`SettingsWidget.qml` & `LockscreenWidget.qml`)

In your extension's QML files, import `org.kde.ki18n` and define a `KI18nContext` specifying your extension's translation domain:

```qml
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.ki18n

ColumnLayout {
    id: root

    // Domain matches your metadata.json translationDomain
    KI18nContext {
        id: kctx
        translationDomain: "io.github.aod4kde.ext.myext"
    }

    QQC2.Label {
        text: kctx.i18n("Custom Settings")
    }

    QQC2.CheckBox {
        text: kctx.i18nc("@option:check", "Enable detailed view")
    }
}
```

When AOD4KDE loads extensions, it automatically registers the extension's `locale/` folder using `KLocalizedString::addDomainLocaleDir()`. This allows `kctx.i18n()` to look up translations from your local `.mo` files without requiring root or system-wide installation.

---

## 4. Building Translation Catalogs

1. **Extract strings to POT template**:
   ```bash
   xgettext --from-code=UTF-8 -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -o po/io.github.aod4kde.ext.myext.pot *.qml
   ```

2. **Initialize or update PO file**:
   ```bash
   # Initialize for Italian
   msginit --locale=it --input=po/io.github.aod4kde.ext.myext.pot -o po/it.po

   # Update existing PO
   msgmerge --update --backup=none po/it.po po/io.github.aod4kde.ext.myext.pot
   ```

3. **Compile to binary MO**:
   ```bash
   mkdir -p locale/it/LC_MESSAGES
   msgfmt po/it.po -o locale/it/LC_MESSAGES/io.github.aod4kde.ext.myext.mo
   ```

---

## See Also
- [Core AOD4KDE i18n Guide](../I18N_GUIDE.md)
- [General Extensions Guide](./README.md)
