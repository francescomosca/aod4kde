# AOD4KDE Guidelines for AI agents

AOD4KDE is a customizable AOD for KDE Plasma (community project).
It works by patching kscreenlocker_greet.
Components:
- aod-tray: tray app
- aod-settings: settings window
- aod-helper: command line tool

## KDE
- AOD4KDE must be compatible with KDE Plasma >=6 on any distro
- Use KDE standards for everything. (Qt>=6.6, KF6, Kirigami, etc)

## Localization
- Code comments and echos must always be in english only
- All strings that can be displayed to the user must handle multiple languages. Follow project configuration (KF6::I18n is the standard here)
- The built-in extensions must have its own locale folder inside its own extension folder (only if the extension needs to display text to the user)

## Tooling & C++ Language Server
- If any task modifies build flags/Makefiles, regenerate `compile_commands.json` by running `python3 tools/generate-compile-commands.py` for clangd support.

## Coding style
- DRY when possible
- Avoid adding new dependencies when possible. Ask the user if it would be worth the trade-off.
- If you need to use JS, write modern ECMAScript (ES6+)

## Versioning & Git Commits
- The single source of truth for versioning is the root `VERSION` file
- Use `tools/bump-version.sh <new_version>` when you need to bump version across the project (PKGBUILDs, extension metadata, changelog)
- Follow Conventional Commits (`feat:`, `fix:`, `perf:`, `refactor:`, `docs:`, `chore:`, etc.) so `git-cliff` can generate clean changelogs
- Release git tags must strictly follow the `vX.Y.Z` SemVer format