import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasma5support as P5Support
import "components" as Comp

Item {
    id: aodWidget
    implicitWidth: 320
    implicitHeight: 280

    // Coordinate offsets for anti burn-in Pixel Shifting
    property real shiftX: 0
    property real shiftY: 0

    // List of installed and available extensions
    property var availableExtensions: []

    // Whether a system battery is detected on this machine
    property bool hasBattery: false

    // Dynamic configuration loaded from file
    property var aodConfig: ({
        "enabled": true,
        "showDate": true,
        "useCustomDateFormat": false,
        "customDateFormat": "ddd, d MMMM",
        "showBattery": false,
        "showBackground": false,
        "backgroundOpacity": 20,
        "onlyOnCustomScreen": false,
        "targetScreen": "",
        "targetScreenModel": "",
        "pixelShiftInterval": 60,
        "scale": 100,
        "clockFont": "system",
        "extensions": {
            "io.github.aod4kde.notifications": { "enabled": true, "config": {} },
            "io.github.aod4kde.sensors": {
                "enabled": false,
                "config": {
                    "coloredSensors": true,
                    "sensors": [
                        { "id": "cpu/all/usage", "label": "CPU", "unit": "%" }
                    ]
                }
            }
        },
        "extensionOrder": ["io.github.aod4kde.notifications", "io.github.aod4kde.sensors"]
    })

    // UI scale factor (50% -> 0.5, 250% -> 2.5)
    readonly property real uiScale: {
        const s = Number(aodConfig.scale);
        return (!isNaN(s) && s >= 50 && s <= 250) ? (s / 100.0) : 1.0;
    }

    // Synchronize scale with Units global singleton
    Binding {
        target: Comp.Units
        property: "scale"
        value: aodWidget.uiScale
    }

    function getFontSource(fontName) {
        let file = "";
        switch (fontName) {
            case "Orbitron": file = "Orbitron.ttf"; break;
            case "Rampart One": file = "RampartOne.ttf"; break;
            case "Rubik Scribble": file = "RubikScribble.ttf"; break;
            case "Press Start 2P": file = "PressStart2P.ttf"; break;
            case "Instrument Serif": file = "InstrumentSerif.ttf"; break;
            default: return "";
        }
        const base = Qt.resolvedUrl(".").toString();
        if (base.indexOf("/src/lockscreen/custom-aod") !== -1) {
            return Qt.resolvedUrl("../../../assets/fonts/" + file);
        }
        return Qt.resolvedUrl("assets/fonts/" + file);
    }

    // On-demand loading of selected clock font only
    FontLoader {
        id: clockFontLoader
        source: getFontSource(aodWidget.aodConfig.clockFont || "system")
    }

    readonly property string clockFontFamily: {
        const f = aodWidget.aodConfig.clockFont || "system";
        if (f === "system" || !f) return "system";
        return clockFontLoader.name || f;
    }

    // Pixel Shifting timer: active ONLY if AOD is enabled and visible
    Timer {
        id: pixelShiftTimer
        interval: (aodConfig.pixelShiftInterval > 0 ? aodConfig.pixelShiftInterval : 60) * 1000
        running: aodWidget.visible && aodConfig.pixelShiftInterval > 0 && aodConfig.enabled !== false
        repeat: true
        onTriggered: {
            const maxShift = 32;
            shiftX = Math.floor(Math.random() * (maxShift * 2 + 1)) - maxShift;
            shiftY = Math.floor(Math.random() * (maxShift * 2 + 1)) - maxShift;
        }
    }

    Behavior on shiftX {
        NumberAnimation { duration: 1500; easing.type: Easing.InOutQuad }
    }

    Behavior on shiftY {
        NumberAnimation { duration: 1500; easing.type: Easing.InOutQuad }
    }

    // DataSource for Date and Time (updates every second)
    P5Support.DataSource {
        id: timeSource
        engine: "time"
        connectedSources: ["Local"]
        interval: 1000
    }

    // Helper for active and ordered extensions
    function isExtensionActive(ext) {
        if (!aodWidget.aodConfig) return false;
        const exts = aodWidget.aodConfig.extensions;
        if (exts && exts[ext.id]) {
            return exts[ext.id].enabled === true;
        }
        return false;
    }

    function getActiveOrderedExtensions() {
        if (!availableExtensions || availableExtensions.length === 0) return [];
        const active = availableExtensions.filter(e => isExtensionActive(e));
        const order = aodWidget.aodConfig.extensionOrder || [];
        return active.sort((a, b) => {
            const idxA = order.indexOf(a.id);
            const idxB = order.indexOf(b.id);
            if (idxA !== -1 && idxB !== -1) return idxA - idxB;
            if (idxA !== -1) return -1;
            if (idxB !== -1) return 1;
            return a.name.localeAwareCompare(b.name);
        });
    }

    function getExtensionConfig(ext) {
        let conf = Object.assign({}, ext.defaultConfig || {});
        if (aodWidget.aodConfig && aodWidget.aodConfig.extensions && aodWidget.aodConfig.extensions[ext.id] && aodWidget.aodConfig.extensions[ext.id].config) {
            conf = Object.assign(conf, aodWidget.aodConfig.extensions[ext.id].config);
        }
        return conf;
    }

    // DataSource to reload configuration and extensions when AOD becomes visible
    P5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            const out = (data["stdout"] || "").trim();
            if (sourceName.indexOf("aod4kde.json") !== -1) {
                try {
                    aodConfig = JSON.parse(out);
                } catch(e) {}
            } else if (sourceName.indexOf("extensions") !== -1) {
                try {
                    const parsed = JSON.parse(out);
                    if (Array.isArray(parsed)) {
                        availableExtensions = parsed;
                    }
                } catch(e) {}
            } else if (sourceName.indexOf("has-battery") !== -1) {
                hasBattery = (out === "true");
            }
            execSource.disconnectSource(sourceName);
        }
    }

    function helperCmd(args) {
        return "if [ -x ~/.local/lib/aod4kde/aod-helper ]; then ~/.local/lib/aod4kde/aod-helper " + args + "; " +
               "elif [ -x /usr/local/lib/aod4kde/aod-helper ]; then /usr/local/lib/aod4kde/aod-helper " + args + "; " +
               "elif [ -x /usr/lib/aod4kde/aod-helper ]; then /usr/lib/aod4kde/aod-helper " + args + "; " +
               "elif [ -x /usr/share/aod4kde/helper/aod-helper ]; then /usr/share/aod4kde/helper/aod-helper " + args + "; fi";
    }

    function reloadData() {
        execSource.connectSource(
            "cat ~/.config/aod4kde.json 2>/dev/null || " +
            "cat ~/.local/share/aod4kde/default-config.json 2>/dev/null || " +
            "cat /usr/local/share/aod4kde/default-config.json 2>/dev/null || " +
            "cat /usr/share/aod4kde/default-config.json 2>/dev/null"
        );
        execSource.connectSource(helperCmd("extensions"));
        execSource.connectSource(helperCmd("has-battery"));
    }

    onVisibleChanged: {
        if (visible) {
            reloadData();
        }
    }

    Component.onCompleted: reloadData()

    // AOD layout shifted by Pixel Shifting (pixel-perfect)
    Item {
        anchors.fill: parent
        visible: aodWidget.aodConfig.enabled !== false
        transform: Translate {
            x: Math.round(aodWidget.shiftX)
            y: Math.round(aodWidget.shiftY)
        }

        // Central block: Clock, Date and Dynamic Extensions
        ColumnLayout {
            id: centerColumn
            anchors.centerIn: parent
            spacing: Comp.Units.dp(14)

            // Clock & Date component
            Comp.ClockDisplay {
                dateTime: timeSource.data["Local"] ? timeSource.data["Local"]["DateTime"] : new Date()
                showDate: aodWidget.aodConfig.showDate !== false
                clockFont: aodWidget.clockFontFamily
                useCustomDateFormat: aodWidget.aodConfig.useCustomDateFormat === true
                customDateFormat: aodWidget.aodConfig.customDateFormat || ""
            }

            // Dynamic AOD extensions loaded in isolation
            Repeater {
                model: aodWidget.getActiveOrderedExtensions()
                delegate: Loader {
                    id: extLoader
                    required property var modelData

                    Layout.alignment: Qt.AlignHCenter
                    visible: status === Loader.Ready
                    source: extLoader.modelData.lockscreenQml || ""

                    onLoaded: {
                        if (item) {
                            try {
                                item.uiScale = aodWidget.uiScale;
                                item.aodConfig = aodWidget.aodConfig;
                                item.extensionConfig = aodWidget.getExtensionConfig(extLoader.modelData);
                                item.aodVisible = Qt.binding(() => aodWidget.visible && aodWidget.aodConfig.enabled !== false);
                            } catch(e) {
                                console.error("Error configuring extension widget:", extLoader.modelData.id, e);
                            }
                        }
                    }
                }
            }
        }

        // Battery indicator (loaded on-demand only when a battery is present and enabled)
        Loader {
            id: batteryLoader
            anchors.horizontalCenter: parent.horizontalCenter

            readonly property real bottomMargin: Math.max(36, Math.round(parent.height * 0.05))
            y: Math.max(centerColumn.y + centerColumn.height + 20, parent.height - height - bottomMargin)

            active: aodWidget.hasBattery && (aodWidget.aodConfig.showBattery !== false)
            source: active ? "components/BatteryDisplay.qml" : ""
        }
    }
}
