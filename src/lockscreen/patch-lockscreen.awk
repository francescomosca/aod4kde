# Before root Item declaration, inject custom-aod directory and AodSync.js imports
/^[[:space:]]*Item[[:space:]]*\{/ && !import_injected {
    print "import \"custom-aod\""
    print "import \"custom-aod/AodSync.js\" as AodSync"
    print ""
    import_injected = 1
}

# Before stock Clock block, inject black background and AodClockStats from overlay file
/^[[:space:]]*Clock[[:space:]]*\{/ && !injected {
    if (overlay_file != "") {
        while ((getline line < overlay_file) > 0) {
            print line
        }
        close(overlay_file)
        print ""
    }
    injected = 1
}

# Ensure stock clock is visible only when lockscreen root UI is visible
/^[[:space:]]*id:[[:space:]]*clock[[:space:]]*$/ && !clock_patched {
    print
    print "            opacity: lockScreenRoot.uiVisible ? 1 : 0"
    clock_patched = 1
    next
}

{ print }

