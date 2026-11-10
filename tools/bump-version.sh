#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$REPO_DIR/VERSION"

if [ -n "$1" ]; then
    NEW_VERSION="$1"
    # Strip optional 'v' prefix
    NEW_VERSION="${NEW_VERSION#v}"
    echo "$NEW_VERSION" > "$VERSION_FILE"
fi

if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: VERSION file not found at $VERSION_FILE" >&2
    exit 1
fi

VERSION="$(tr -d ' \n\r' < "$VERSION_FILE")"
echo "==> Syncing project to version: $VERSION"

# 1. Update Arch PKGBUILDs
for pkgbuild in "$REPO_DIR/packaging/arch/aod4kde/PKGBUILD" "$REPO_DIR/packaging/arch/aod4kde-bin/PKGBUILD"; do
    if [ -f "$pkgbuild" ]; then
        echo "  -> Updating $(realpath --relative-to="$REPO_DIR" "$pkgbuild")"
        sed -i -E "s/^pkgver=.*/pkgver=$VERSION/" "$pkgbuild"
        sed -i -E "s/^pkgrel=.*/pkgrel=1/" "$pkgbuild"
    fi
done

# 2. Update built-in extension metadata.json files
for meta in "$REPO_DIR"/src/extensions/*/metadata.json; do
    if [ -f "$meta" ]; then
        echo "  -> Updating $(realpath --relative-to="$REPO_DIR" "$meta")"
        sed -i -E "s/\"version\": \"[^\"]+\"/\"version\": \"$VERSION\"/" "$meta"
    fi
done

# 3. Update CHANGELOG.md if git-cliff and .git repo exist
if command -v git-cliff >/dev/null 2>&1 && [ -d "$REPO_DIR/.git" ]; then
    echo "  -> Generating CHANGELOG.md with git-cliff..."
    git-cliff --tag "v$VERSION" --output "$REPO_DIR/CHANGELOG.md"
else
    echo "  (git-cliff or .git not detected, skipping local CHANGELOG generation)"
fi

echo "[OK] Version sync complete: $VERSION"

