import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import org.kde.ki18n
import "components" as Comp

QQC2.ApplicationWindow {
    id: window
    // title: ki18n.i18nc("@title:window", "AOD Settings")
    width: 740
    height: 600
    minimumWidth: 580
    minimumHeight: 480
    visible: true

    KI18nContext {
        id: ki18n
        translationDomain: "aod4kde"
    }

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false
    color: Kirigami.Theme.backgroundColor

    property int currentTab: 0
    property bool hasUnsavedChanges: false
    property bool quitAfterSave: false
    property string savedConfigSnapshot: ""
    property bool isDpmsActive: false
    property bool isIncompatible: (typeof initialIsIncompatible !== "undefined") ? initialIsIncompatible : false
    property bool hasBattery: (typeof initialHasBattery !== "undefined") ? initialHasBattery : true

    onActiveChanged: {
        if (active) {
            checkDpms();
            checkCompatibility();
        }
    }

    // Spinner state for immediate master switch saving
    property bool isSavingEnabled: false
    property bool pendingSaveEnabledDone: false

    property var currentConfig: {
        if (typeof initialConfigJson !== "undefined" && initialConfigJson.length > 0) {
            try {
                const parsed = JSON.parse(initialConfigJson);
                if (!hasBattery) {
                    parsed.showBattery = false;
                }
                return parsed;
            } catch(e) {
                console.log("Error parsing initial config json:", e);
            }
        }
        return ({
            "enabled": true,
            "showDate": true,
            "useCustomDateFormat": false,
            "customDateFormat": "ddd, d MMMM",
            "showBattery": true,
            "showBackground": false,
            "backgroundOpacity": 20,
            "onlyOnCustomScreen": false,
            "targetScreen": "",
            "targetScreenModel": "",
            "pixelShiftInterval": 60,
            "scale": 100,
            "clockFont": "system",
            "extensions": {},
            "extensionOrder": []
        });
    }

    property var availableExtensionsList: {
        if (typeof initialExtensionsJson !== "undefined" && initialExtensionsJson.length > 0) {
            try {
                const parsedExt = JSON.parse(initialExtensionsJson);
                if (Array.isArray(parsedExt)) {
                    return parsedExt;
                }
            } catch(e) {
                console.log("Error parsing initial extensions json:", e);
            }
        }
        return [];
    }

    readonly property var categoriesModel: [
        { name: ki18n.i18nc("@item:inmenu", "Appearance"), icon: "preferences-desktop-color" },
        { name: ki18n.i18nc("@item:inmenu", "Extensions"), icon: "preferences-plugin" },
        { name: ki18n.i18nc("@item:inmenu", "Behavior"), icon: "preferences-system" },
        { name: ki18n.i18nc("@item:inmenu", "About"), icon: "help-about" }
    ]

    Timer {
        id: minSpinnerTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (window.pendingSaveEnabledDone) {
                window.isSavingEnabled = false;
            }
        }
    }

    P5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            const out = (data["stdout"] || "").trim();
            if (sourceName.indexOf("#load-config") !== -1) {
                try {
                    const parsed = JSON.parse(out);
                    if (!window.hasBattery) {
                        parsed.showBattery = false;
                    }
                    window.currentConfig = parsed;
                    window.savedConfigSnapshot = JSON.stringify(window.currentConfig);
                    window.hasUnsavedChanges = false;
                    updateUiFromConfig();
                } catch(e) {
                    console.log("Errore parsing config json");
                }
            } else if (sourceName.indexOf("#has-battery") !== -1) {
                window.hasBattery = (out === "true");
                if (!window.hasBattery && window.currentConfig) {
                    window.currentConfig.showBattery = false;
                    try {
                        let snap = JSON.parse(window.savedConfigSnapshot);
                        snap.showBattery = false;
                        window.savedConfigSnapshot = JSON.stringify(snap);
                    } catch(e) {}
                    window.hasUnsavedChanges = (JSON.stringify(window.currentConfig) !== window.savedConfigSnapshot);
                }
                tabAppearance.syncFromConfig();
            } else if (sourceName.indexOf("#get-extensions") !== -1) {
                try {
                    const parsedExt = JSON.parse(out);
                    if (Array.isArray(parsedExt)) {
                        window.availableExtensionsList = parsedExt;
                        tabExtensions.syncFromConfig();
                    }
                } catch(e) {
                    console.log("Errore parsing lista estensioni:", e);
                }
            } else if (sourceName.indexOf("#save-enabled") !== -1) {
                window.pendingSaveEnabledDone = true;
                if (!minSpinnerTimer.running) {
                    window.isSavingEnabled = false;
                }
            } else if (sourceName.indexOf("#apply-config") !== -1) {
                window.savedConfigSnapshot = JSON.stringify(window.currentConfig);
                window.hasUnsavedChanges = false;
                tabExtensions.syncFromConfig();
                if (window.quitAfterSave) {
                    Qt.quit();
                }
            } else if (sourceName.indexOf("#check-dpms") !== -1) {
                window.isDpmsActive = (out.indexOf("DPMS_ACTIVE:true") !== -1);
            } else if (sourceName.indexOf("#check-compat") !== -1) {
                window.isIncompatible = (out.indexOf("AOD_INCOMPATIBLE:true") !== -1);
            }
            execSource.disconnectSource(sourceName);
        }
    }

    function checkDpms() {
        execSource.connectSource(helperCmd("check-dpms") + " #check-dpms");
    }

    function checkCompatibility() {
        const cmd = "sh -c '" +
            "if [ -f /usr/share/aod4kde/lockscreen/.patch_failed ] || " +
            "([ -f /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockScreenUi.qml ] && " +
            "! grep -q \"id: aodManager\" /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockScreenUi.qml); then " +
            "echo \"AOD_INCOMPATIBLE:true\"; else echo \"AOD_INCOMPATIBLE:false\"; fi' #check-compat";
        execSource.connectSource(cmd);
    }

    function helperCmd(args) {
        const localHelper = Qt.resolvedUrl("../helper/aod-helper").toString().replace("file://", "");
        return "if [ -x \"" + localHelper + "\" ]; then \"" + localHelper + "\" " + args + "; " +
               "elif [ -x ~/.local/lib/aod4kde/aod-helper ]; then ~/.local/lib/aod4kde/aod-helper " + args + "; " +
               "elif [ -x /usr/local/lib/aod4kde/aod-helper ]; then /usr/local/lib/aod4kde/aod-helper " + args + "; " +
               "elif [ -x /usr/lib/aod4kde/aod-helper ]; then /usr/lib/aod4kde/aod-helper " + args + "; fi";
    }

    function reloadExtensions() {
        execSource.connectSource(helperCmd("extensions") + " #get-extensions");
    }

    function runCommand(cmd) {
        execSource.connectSource(cmd + " #run-cmd");
    }

    function loadConfig() {
        window.savedConfigSnapshot = JSON.stringify(window.currentConfig);
        updateUiFromConfig();
        execSource.connectSource(
            "cat ~/.config/aod4kde.json 2>/dev/null || " +
            "cat ~/.local/share/aod4kde/default-config.json 2>/dev/null || " +
            "cat /usr/local/share/aod4kde/default-config.json 2>/dev/null || " +
            "cat /usr/share/aod4kde/default-config.json 2>/dev/null #load-config"
        );
        execSource.connectSource(helperCmd("has-battery") + " #has-battery");
        reloadExtensions();
        checkDpms();
        checkCompatibility();
    }

    function markChanged() {
        window.hasUnsavedChanges = (JSON.stringify(window.currentConfig) !== window.savedConfigSnapshot);
    }

    function stringToHex(s) {
        let hex = "";
        const encoded = encodeURIComponent(s);
        for (let i = 0; i < encoded.length; i++) {
            if (encoded[i] === '%') {
                hex += encoded.substr(i + 1, 2);
                i += 2;
            } else {
                hex += encoded.charCodeAt(i).toString(16).padStart(2, '0');
            }
        }
        return hex;
    }

    function saveEnabledImmediate(enabled) {
        window.currentConfig.enabled = enabled;

        // Update only "enabled" in the base snapshot, preserving pending UI changes
        let baseObj = {};
        try {
            baseObj = JSON.parse(window.savedConfigSnapshot);
        } catch(e) {
            baseObj = Object.assign({}, window.currentConfig);
        }
        baseObj.enabled = enabled;
        window.savedConfigSnapshot = JSON.stringify(baseObj);
        markChanged();

        window.isSavingEnabled = true;
        window.pendingSaveEnabledDone = false;
        minSpinnerTimer.restart();

        const hex = stringToHex(window.savedConfigSnapshot);
        const cmd = helperCmd("save --hex " + hex) + " #save-enabled";
        execSource.connectSource(cmd);
    }

    function applyConfig() {
        const jsonStr = JSON.stringify(window.currentConfig);
        const hex = stringToHex(jsonStr);
        const cmd = helperCmd("save --hex " + hex) + " #apply-config";
        execSource.connectSource(cmd);
    }

    function removeExtension(extId, keepSettings) {
        if (!extId) return;

        if (!window.currentConfig.extensions) {
            window.currentConfig.extensions = {};
        }
        if (!Array.isArray(window.currentConfig.extensionOrder)) {
            window.currentConfig.extensionOrder = [];
        }

        if (keepSettings) {
            const existingCfg = (window.currentConfig.extensions[extId] && window.currentConfig.extensions[extId].config)
                ? window.currentConfig.extensions[extId].config
                : {};
            window.currentConfig.extensions[extId] = {
                "enabled": false,
                "config": existingCfg
            };
        } else {
            delete window.currentConfig.extensions[extId];
            window.currentConfig.extensionOrder = window.currentConfig.extensionOrder.filter(id => id !== extId);
        }

        let baseObj = {};
        try {
            baseObj = JSON.parse(window.savedConfigSnapshot);
        } catch(e) {
            baseObj = JSON.parse(JSON.stringify(window.currentConfig));
        }
        if (!baseObj.extensions) baseObj.extensions = {};
        if (!Array.isArray(baseObj.extensionOrder)) baseObj.extensionOrder = [];

        if (keepSettings) {
            baseObj.extensions[extId] = JSON.parse(JSON.stringify(window.currentConfig.extensions[extId]));
        } else {
            delete baseObj.extensions[extId];
            baseObj.extensionOrder = baseObj.extensionOrder.filter(id => id !== extId);
        }
        window.savedConfigSnapshot = JSON.stringify(baseObj);
        markChanged();

        window.availableExtensionsList = (window.availableExtensionsList || []).filter(e => e.id !== extId);
        tabExtensions.syncFromConfig();

        const hex = stringToHex(window.savedConfigSnapshot);
        const safeId = extId.replace(/[^a-zA-Z0-9._-]/g, "");
        const cmd = helperCmd("remove-extension \"" + safeId + "\" >/dev/null 2>&1") + "; " +
                    helperCmd("save --hex " + hex + " >/dev/null 2>&1") + "; " +
                    helperCmd("extensions") + " #get-extensions";
        execSource.connectSource(cmd);
    }

    function retryDaemon(extId) {
        if (!extId) return;
        const safeId = extId.replace(/[^a-zA-Z0-9._-]/g, "");
        const cmd = helperCmd("reset-daemon-failure " + safeId) + " >/dev/null 2>&1; " +
                    helperCmd("extensions") + " #get-extensions";
        execSource.connectSource(cmd);
    }

    function updateUiFromConfig() {
        tabAppearance.syncFromConfig();
        tabExtensions.syncFromConfig();
        tabBehavior.syncFromConfig();
    }

    Component.onCompleted: {
        if (typeof initialConfigJson !== "undefined") {
            updateUiFromConfig();
            window.savedConfigSnapshot = JSON.stringify(window.currentConfig);
            window.hasUnsavedChanges = false;
            checkDpms();
        } else {
            loadConfig();
        }
    }

    // =========================================================
    // MAIN LAYOUT: GLOBAL HEADER + (SIDEBAR + PAGE) + FOOTER
    // =========================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 1. GLOBAL WINDOW HEADER (INSTANT AOD MASTER SWITCH)
        Rectangle {
            id: globalHeader
            Layout.fillWidth: true
            implicitHeight: headerCol.implicitHeight + (Kirigami.Units.largeSpacing * 2)
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
            Kirigami.Theme.inherit: false
            color: Kirigami.Theme.backgroundColor

            ColumnLayout {
                id: headerCol
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.largeSpacing * 1.5
                anchors.rightMargin: Kirigami.Units.largeSpacing * 1.5
                anchors.topMargin: Kirigami.Units.largeSpacing
                anchors.bottomMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.mediumSpacing

                RowLayout {
                    id: headerRow
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    // Title & Subtitle
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: ki18n.i18n("Always-On-Display Mode")
                            font.bold: true
                            font.pixelSize: 15
                            elide: Text.ElideRight
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: ki18n.i18n("Show clock and extensions on the lockscreen")
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    // Instant save spinner
                    QQC2.BusyIndicator {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        running: window.isSavingEnabled
                        visible: window.isSavingEnabled
                    }

                    // Master Switch AOD
                    QQC2.Switch {
                        id: aodMasterSwitch
                        enabled: !window.isSavingEnabled && !window.isIncompatible
                        checked: !window.isIncompatible && window.currentConfig && window.currentConfig.enabled !== false
                        onToggled: {
                            window.saveEnabledImmediate(checked);
                        }
                    }
                }

                Kirigami.InlineMessage {
                    id: incompatibleErrorMessage
                    Layout.fillWidth: true
                    visible: window.isIncompatible
                    type: Kirigami.MessageType.Error
                    text: ki18n.i18n("There was a problem applying Always-On-Display to the system lockscreen. Please wait for an AOD4KDE update. Your settings remain available below.")
                }

                Kirigami.InlineMessage {
                    id: dpmsWarningMessage
                    Layout.fillWidth: true
                    visible: window.isDpmsActive
                    type: Kirigami.MessageType.Warning
                    text: ki18n.i18n("Display power management (DPMS) is active: to display AOD, you should disable display turn-off or set its timeout higher than the screen lock timeout.")
                    actions: [
                        Kirigami.Action {
                            text: ki18n.i18nc("@action:button", "Fix…")
                            icon.name: "preferences-system-power-management"
                            onTriggered: {
                                window.runCommand("kcmshell6 kcm_powerdevilprofilesconfig 2>/dev/null || systemsettings kcm_powerdevilprofilesconfig");
                            }
                        }
                    ]
                }
            }
        }

        // Top divider line below global header
        Kirigami.Separator {
            Layout.fillWidth: true
            z: 2
        }

        // 2. CENTRAL BODY: SIDEBAR + PAGES
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // CATEGORIES SIDEBAR ON THE LEFT
            QQC2.ScrollView {
                id: categoriesScroll
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: Kirigami.Units.gridUnit * 7.5
                contentWidth: availableWidth
                Kirigami.Theme.colorSet: Kirigami.Theme.View
                Kirigami.Theme.inherit: false
                activeFocusOnTab: true
                focus: true
                Accessible.role: Accessible.PageTabList

                background: Rectangle {
                    color: Kirigami.Theme.backgroundColor
                }

                Keys.onUpPressed: (event) => {
                    if (window.currentTab > 0) {
                        window.currentTab--;
                        event.accepted = true;
                    }
                }

                Keys.onDownPressed: (event) => {
                    if (window.currentTab < window.categoriesModel.length - 1) {
                        window.currentTab++;
                        event.accepted = true;
                    }
                }

                ColumnLayout {
                    id: categoriesColumn
                    spacing: 0
                    width: categoriesScroll.contentWidth

                    Repeater {
                        model: window.categoriesModel
                        delegate: QQC2.ItemDelegate {
                            id: tabDelegate
                            required property int index
                            required property var modelData

                            Layout.fillWidth: true
                            hoverEnabled: true
                            highlighted: window.currentTab === index

                            onClicked: {
                                window.currentTab = index;
                                categoriesScroll.forceActiveFocus(Qt.MouseFocusReason);
                            }

                            contentItem: ColumnLayout {
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: Kirigami.Units.iconSizes.medium
                                    implicitHeight: Kirigami.Units.iconSizes.medium
                                    source: tabDelegate.modelData.icon
                                    selected: Window.active && (tabDelegate.highlighted || tabDelegate.pressed)
                                }

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Kirigami.Units.smallSpacing
                                    Layout.rightMargin: Kirigami.Units.smallSpacing
                                    text: tabDelegate.modelData.name
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Window.active && (tabDelegate.highlighted || tabDelegate.pressed)
                                           ? Kirigami.Theme.highlightedTextColor
                                           : Kirigami.Theme.textColor
                                    font.bold: tabDelegate.highlighted && categoriesScroll.activeFocus
                                }
                            }
                        }
                    }
                }
            }

            // Vertical divider between Sidebar and Content
            Kirigami.Separator {
                id: verticalSeparator
                anchors {
                    top: parent.top
                    left: categoriesScroll.right
                    bottom: parent.bottom
                }
                z: 2
            }

            // RIGHT AREA: PAGE CONTENT
            QQC2.ScrollView {
                id: pageScrollView
                anchors {
                    top: parent.top
                    left: verticalSeparator.right
                    right: parent.right
                    bottom: parent.bottom
                }
                clip: true
                contentWidth: availableWidth

                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                ColumnLayout {
                    width: pageScrollView.availableWidth
                    spacing: Kirigami.Units.largeSpacing

                    // Page Title Header
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 1.5
                        Layout.rightMargin: Kirigami.Units.largeSpacing * 1.5
                        Layout.topMargin: Kirigami.Units.largeSpacing * 1.25
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Heading {
                            level: 1
                            text: window.categoriesModel[window.currentTab].name
                            Layout.fillWidth: true
                        }
                    }

                    // Stack of the 4 Tabs
                    StackLayout {
                        id: pagesStack
                        Layout.fillWidth: true
                        Layout.preferredHeight: children[currentIndex] ? children[currentIndex].implicitHeight : 0
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 1.5
                        Layout.rightMargin: Kirigami.Units.largeSpacing * 1.5
                        Layout.bottomMargin: Kirigami.Units.largeSpacing * 1.5
                        currentIndex: window.currentTab

                        onCurrentIndexChanged: {
                            if (pageScrollView.contentItem) {
                                pageScrollView.contentItem.contentY = 0;
                            }
                        }

                        Comp.TabAppearance {
                            id: tabAppearance
                            config: window.currentConfig
                            hasBattery: window.hasBattery
                            onSettingModified: window.markChanged()
                        }

                        Comp.TabExtensions {
                            id: tabExtensions
                            config: window.currentConfig
                            extensionsList: window.availableExtensionsList
                            appWindow: window
                            onSettingModified: window.markChanged()
                            onRequestReloadExtensions: window.reloadExtensions()
                            onRequestRemoveExtension: (extId, keepSettings) => window.removeExtension(extId, keepSettings)
                        }

                        Comp.TabBehavior {
                            id: tabBehavior
                            config: window.currentConfig
                            onSettingModified: window.markChanged()
                            onRunCommand: (cmd) => execSource.connectSource(cmd)
                        }

                        Comp.TabAbout {
                            id: tabAbout
                        }
                    }
                }
            }
        }

        // Separator above Footer
        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // 3. BUTTON FOOTER (Test AOD, OK, Apply, Cancel)
        QQC2.Pane {
            Layout.fillWidth: true
            padding: Kirigami.Units.largeSpacing

            background: Rectangle {
                color: Kirigami.Theme.backgroundColor
            }

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.Button {
                    text: ki18n.i18nc("@action:button", "Test AOD (Lock Screen)")
                    icon.name: "system-lock-screen"
                    onClicked: window.runCommand("loginctl lock-session")
                }

                Item {
                    Layout.fillWidth: true
                }

                QQC2.Button {
                    icon.name: "dialog-ok"
                    text: ki18n.i18nc("@action:button", "OK")
                    onClicked: {
                        if (window.hasUnsavedChanges) {
                            window.quitAfterSave = true;
                            window.applyConfig();
                        } else {
                            Qt.quit();
                        }
                    }
                }

                QQC2.Button {
                    id: applyButton
                    enabled: window.hasUnsavedChanges
                    icon.name: "dialog-ok-apply"
                    text: ki18n.i18nc("@action:button", "Apply")
                    visible: window.currentTab !== 3
                    onClicked: window.applyConfig()
                }

                QQC2.Button {
                    icon.name: "dialog-cancel"
                    text: ki18n.i18nc("@action:button", "Cancel")
                    visible: window.currentTab !== 3
                    onClicked: Qt.quit()
                }
            }
        }
    }
}
