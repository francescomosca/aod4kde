# KDE KF6 Internationalization (i18n) & Localization (l10n) Guide

This guide summarizes the essential rules and workflow for internationalization (i18n) and localization (l10n) in AOD4KDE, following standard KDE Frameworks 6 (`KF6::I18n`) and GNU Gettext conventions.

---

## 1. Core Principles

1. **Source Code is English**: All strings in the source code (`msgid`) MUST be written in English.
2. **Translations are in PO Catalogs**: Other languages (such as Italian) are stored in translation catalogs located in `po/<lang>.po` (e.g. `po/it.po`).
3. **No Word Puzzles**: Never concatenate translated strings or assemble sentences out of fragments. Always use placeholders (`%1`, `%2`, etc.).
   ```cpp
   // BAD:
   i18n("File ") + name + i18n(" not found.");
   // GOOD:
   i18n("File %1 not found.", name);
   ```
4. **Use Disambiguation Contexts**: Use `i18nc()` whenever a word or short phrase could have multiple meanings in different contexts or parts of speech (e.g. verb vs noun).
5. **Use Plural Forms**: Always use `i18np()` when a message involves a variable count:
   ```cpp
   i18np("%1 item selected", "%1 items selected", count);
   ```

---

## 2. C++ Usage (`KF6::I18n`)

### Application Initialization
In `main()`, set the application translation domain right after creating `QCoreApplication` / `QApplication`:
```cpp
#include <klocalizedstring.h>

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    KLocalizedString::setApplicationDomain("aod4kde");
    // ...
}
```

### String Macros
```cpp
// Simple message
QString msg = i18n("Settings");

// Message with context (UI marker + clarification)
QString btn = i18nc("@action:button", "Save");

// Message with plural
QString countStr = i18np("%1 second", "%1 seconds", sec);

// Message with context and plural
QString files = i18ncp("@info:status", "%1 file left", "%1 files left", count);
```

### Context UI Markers
KDE translators rely on standardized UI markers prefixed in the context:
- `@action:button`: Push button label
- `@action:inmenu`: Menu item action
- `@title:window`: Window title
- `@title:group`: Groupbox / section title
- `@option:check`: Checkbox label
- `@option:radio`: Radio button label
- `@label`: General widget label
- `@item:inlistbox`: Item inside combo/list box
- `@info:tooltip`: Tooltip text
- `@info:status`: Statusbar / state text

---

## 3. QML Usage (`org.kde.ki18n`)

In QML files running under Qt6 / Plasma, translations are accessed using `KI18nContext`:

```qml
import QtQuick
import org.kde.ki18n

Item {
    KI18nContext {
        id: kctx
        translationDomain: "aod4kde"
    }

    Text {
        text: kctx.i18n("Appearance")
    }

    Text {
        text: kctx.i18nc("@info:status", "AOD is active")
    }
}
```

---

## 4. PO Workflow & Commands

### Extracting and Updating Translations
Run the provided helper script:
```bash
./tools/update-translations.sh
```

Under the hood, this performs:
1. **Extraction**: `xgettext` scans C++ and QML files to generate `po/aod4kde.pot`.
2. **Merging**: `msgmerge` updates existing catalogs (e.g. `po/it.po`) against the new `.pot` template without destroying translations.
3. **Compiling**: `msgfmt` compiles `.po` into runtime binary `.mo` files:
   ```bash
   msgfmt po/it.po -o po/it/LC_MESSAGES/aod4kde.mo
   ```

### Installation Target Paths
Installed `.mo` files must follow the standard Gettext directory structure:
- User: `~/.local/share/locale/<lang>/LC_MESSAGES/<domain>.mo`
- System: `/usr/share/locale/<lang>/LC_MESSAGES/<domain>.mo`

---

## 5. Third-Party Extensions Localization

Third-party extensions can be fully localized without modifying core AOD files.
For complete instructions, examples, and directory layouts, see:
- [Extension Localization Guide](./custom_extensions/LOCALIZATION.md)
- [Extension Guide](./custom_extensions/README.md)
