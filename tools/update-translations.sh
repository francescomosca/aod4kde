#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PO_DIR="$REPO_DIR/po"
POT_FILE="$PO_DIR/aod4kde.pot"

mkdir -p "$PO_DIR"

echo "=========================================="
echo "   AOD4KDE Core Translations"
echo "=========================================="

echo "==> 1/3 Extracting core strings from C++ and QML files..."

# Collect core source files (excluding extensions)
SOURCES_FILE="$(mktemp /tmp/aod_sources_XXXXXX.list)"
(cd "$REPO_DIR" && find src/tray src/helper src/common src/settings src/lockscreen \
     \( -name "*.cpp" -o -name "*.h" -o -name "*.qml" \) -not -name "moc_*.cpp" | sort) > "$SOURCES_FILE"

xgettext \
    --directory="$REPO_DIR" \
    --from-code=UTF-8 \
    --c++ \
    --kde \
    --add-comments=i18n \
    -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 \
    -kki18n:1 -kki18nc:1c,2 -kki18np:1,2 -kki18ncp:1c,2,3 \
    -kxi18n:1 -kxi18nc:1c,2 -kxi18np:1,2 -kxi18ncp:1c,2,3 \
    --package-name="aod4kde" \
    --msgid-bugs-address="https://github.com/francescomosca/aod4kde/issues" \
    -f "$SOURCES_FILE" \
    -o "$POT_FILE"

rm -f "$SOURCES_FILE"
echo "    Template generated: $POT_FILE"

echo "==> 2/3 Merging core .po catalogs..."
for PO_FILE in "$PO_DIR"/*.po; do
    [ -f "$PO_FILE" ] || continue
    LANG_CODE="$(basename "$PO_FILE" .po)"
    echo "    Updating $LANG_CODE ($PO_FILE)..."
    msgmerge --update --backup=none --previous "$PO_FILE" "$POT_FILE"
done

echo "==> 3/3 Compiling core binary .mo message catalogs..."
for PO_FILE in "$PO_DIR"/*.po; do
    [ -f "$PO_FILE" ] || continue
    LANG_CODE="$(basename "$PO_FILE" .po)"
    TARGET_DIR="$PO_DIR/$LANG_CODE/LC_MESSAGES"
    mkdir -p "$TARGET_DIR"
    msgfmt "$PO_FILE" -o "$TARGET_DIR/aod4kde.mo"
    echo "    Compiled: $TARGET_DIR/aod4kde.mo"
done

echo ""
echo "=========================================="
echo "   Extensions Translations"
echo "=========================================="

for EXT_DIR in "$REPO_DIR/src/extensions"/*; do
    [ -d "$EXT_DIR" ] || continue
    EXT_ID="$(basename "$EXT_DIR")"
    EXT_PO_DIR="$EXT_DIR/po"
    
    # If the extension has a po/ directory or translatable QML files
    if [ -d "$EXT_PO_DIR" ]; then
        echo "--> Processing extension: $EXT_ID"
        EXT_POT="$EXT_PO_DIR/$EXT_ID.pot"
        
        EXT_SOURCES="$(mktemp /tmp/ext_sources_XXXXXX.list)"
        (cd "$EXT_DIR" && find . -maxdepth 2 \( -name "*.qml" -o -name "*.cpp" -o -name "*.h" \) | sed 's|^\./||' | sort) > "$EXT_SOURCES"
        
        if [ -s "$EXT_SOURCES" ]; then
            xgettext \
                --directory="$EXT_DIR" \
                --from-code=UTF-8 \
                --c++ \
                --kde \
                --add-comments=i18n \
                -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 \
                -kki18n:1 -kki18nc:1c,2 -kki18np:1,2 -kki18ncp:1c,2,3 \
                -kxi18n:1 -kxi18nc:1c,2 -kxi18np:1,2 -kxi18ncp:1c,2,3 \
                --package-name="$EXT_ID" \
                -f "$EXT_SOURCES" \
                -o "$EXT_POT"
            echo "    Extension POT generated: $EXT_POT"
        fi
        rm -f "$EXT_SOURCES"
        
        for EXT_PO in "$EXT_PO_DIR"/*.po; do
            [ -f "$EXT_PO" ] || continue
            LANG_CODE="$(basename "$EXT_PO" .po)"
            if [ -f "$EXT_POT" ]; then
                msgmerge --update --backup=none --previous "$EXT_PO" "$EXT_POT"
            fi
            
            # Compile to <ext>/locale/<lang>/LC_MESSAGES/<domain>.mo
            EXT_LOCALE_DIR="$EXT_DIR/locale/$LANG_CODE/LC_MESSAGES"
            mkdir -p "$EXT_LOCALE_DIR"
            msgfmt "$EXT_PO" -o "$EXT_LOCALE_DIR/$EXT_ID.mo"
            echo "    Compiled: $EXT_LOCALE_DIR/$EXT_ID.mo"
        done
    fi
done

echo ""
echo "==> All translations successfully updated and compiled!"
