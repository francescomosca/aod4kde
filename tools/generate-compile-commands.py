#!/usr/bin/env python3
import json
import os
import subprocess

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

targets = [
    ("src/helper", "aod-helper.cpp", "helper"),
    ("src/tray", "aod-tray.cpp", "tray"),
    ("src/tray", "ExtensionSupervisor.cpp", "tray"),
    ("src/settings", "aod-settings.cpp", "settings"),
    ("src/extensions/io.github.aod4kde.notifications/daemon", "aod-ext-notifications.cpp", "daemon"),
    ("src/extensions/io.github.aod4kde.sensors/daemon", "aod-ext-sensors.cpp", "daemon"),
    ("docs/custom_extensions/examples/with_settings_and_daemon/daemon", "main.cpp", "daemon"),
]

entries = []

for rel_dir, src_file, target in targets:
    abs_dir = os.path.join(ROOT_DIR, rel_dir)
    if not os.path.exists(abs_dir):
        continue

    makefile = os.path.join(abs_dir, "Makefile")
    if not os.path.exists(makefile):
        continue

    # Ensure MOC files are generated in build/ so clangd can resolve #include "*.moc"
    subprocess.run(["make", "moc"], cwd=abs_dir, capture_output=True, text=True)

    # Run make -B -n to dry-run build commands
    res = subprocess.run(["make", "-B", "-n"], cwd=abs_dir, capture_output=True, text=True)
    compile_cmd = None
    for line in res.stdout.splitlines():
        line_s = line.strip()
        if (line_s.startswith("g++") or line_s.startswith("clang++") or "g++ " in line_s) and src_file in line_s:
            compile_cmd = line_s
            break

    if compile_cmd:
        entries.append({
            "directory": abs_dir,
            "command": compile_cmd,
            "file": os.path.join(abs_dir, src_file)
        })

out_path = os.path.join(ROOT_DIR, "compile_commands.json")
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(entries, f, indent=2)

print(f"Generated {out_path} with {len(entries)} entries.")
