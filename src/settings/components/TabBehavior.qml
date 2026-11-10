import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.ki18n

ColumnLayout {
    id: root
    spacing: Kirigami.Units.largeSpacing

    required property var config
    signal settingModified()
    signal runCommand(string command)

    KI18nContext {
        id: ki18n
        translationDomain: "aod4kde"
    }

    function updateScreenModel() {
        if (!root.config) return;

        const screens = Qt.application.screens ?? [];
        const savedName = root.config.targetScreen ?? "";
        let savedModel = root.config.targetScreenModel ?? "";

        const list = screens.map((s, index) => {
            const screenName = s.name || `screen_${index}`;
            const modelName = s.model?.trim() || "";
            const label = (modelName && modelName !== screenName)
                ? `${modelName} (${screenName})`
                : screenName;

            if (screenName === savedName && modelName) {
                savedModel = modelName;
            }

            return {
                screenName,
                modelName,
                label,
                connected: true
            };
        });

        const foundSaved = list.some(item => item.screenName === savedName);

        // Keep previously selected screen reference if not currently connected
        if (savedName && !foundSaved) {
            const disconnectedSuffix = ki18n.i18nc("@item:inlistbox", "disconnected");
            const disconnectedLabel = savedModel
                ? `${savedModel} (${savedName} - ${disconnectedSuffix})`
                : `${savedName} (${disconnectedSuffix})`;

            list.push({
                screenName: savedName,
                modelName: savedModel,
                label: disconnectedLabel,
                connected: false
            });
        }

        targetScreenCombo.model = list;

        const targetIndex = Math.max(0, list.findIndex(item => item.screenName === savedName));
        targetScreenCombo.currentIndex = targetIndex;

        if (list[targetIndex]) {
            targetScreenCombo.currentModelName = list[targetIndex].modelName;
            if (!savedName && list[targetIndex].screenName && root.config.onlyOnCustomScreen) {
                root.config.targetScreen = list[targetIndex].screenName;
                root.config.targetScreenModel = list[targetIndex].modelName;
            }
        }
    }

    function syncFromConfig() {
        if (!root.config) return;

        const intervalMap = { 60: 0, 180: 1, 300: 2, 0: 3 };
        const interval = root.config.pixelShiftInterval ?? 60;
        pixelShiftCombo.currentIndex = intervalMap[interval] ?? (interval <= 0 ? 3 : 0);

        onlyOnCustomScreenSwitch.checked = Boolean(root.config.onlyOnCustomScreen);
        updateScreenModel();
    }

    Connections {
        target: Qt.application
        function onScreensChanged() {
            root.updateScreenModel();
        }
    }

    QQC2.Label {
        text: ki18n.i18n("Burn-In Protection (Pixel Shifting):")
        color: Kirigami.Theme.textColor
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            QQC2.Label {
                text: ki18n.i18n("Pixel shift frequency:")
                Layout.fillWidth: true
            }

            QQC2.ComboBox {
                id: pixelShiftCombo
                Layout.preferredWidth: 200
                model: [
                    ki18n.i18n("Every 1 minute"),
                    ki18n.i18n("Every 3 minutes"),
                    ki18n.i18n("Every 5 minutes"),
                    ki18n.i18n("Never (not recommended)")
                ]
                onActivated: (index) => {
                    let sec = 60;
                    if (index === 0) sec = 60;
                    else if (index === 1) sec = 180;
                    else if (index === 2) sec = 300;
                    else if (index === 3) sec = 0;
                    root.config.pixelShiftInterval = sec;
                    root.settingModified();
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: ki18n.i18n("Periodically shifts screen elements to prevent OLED burn-in.")
            font.pixelSize: 11
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
    }

    QQC2.Label {
        text: ki18n.i18n("Multiple Displays:")
        color: Kirigami.Theme.textColor
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        QQC2.CheckBox {
            id: onlyOnCustomScreenSwitch
            Layout.fillWidth: true
            text: ki18n.i18n("Show AOD only on this screen:")
            onToggled: {
                root.config.onlyOnCustomScreen = checked;
                if (checked && (!root.config.targetScreen || root.config.targetScreen === "")) {
                    if (targetScreenCombo.model && targetScreenCombo.model.length > 0) {
                        const curIdx = Math.max(0, targetScreenCombo.currentIndex);
                        const item = targetScreenCombo.model[curIdx];
                        root.config.targetScreen = item.screenName;
                        root.config.targetScreenModel = item.modelName || "";
                    }
                }
                root.settingModified();
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing * 1.5
            spacing: Kirigami.Units.mediumSpacing

            QQC2.ComboBox {
                id: targetScreenCombo
                Layout.fillWidth: true
                enabled: onlyOnCustomScreenSwitch.checked
                textRole: "label"
                valueRole: "screenName"
                property string currentModelName: ""
                model: []

                onActivated: (index) => {
                    if (index >= 0 && index < model.length) {
                        const item = model[index];
                        root.config.targetScreen = item.screenName;
                        root.config.targetScreenModel = item.modelName || "";
                        currentModelName = item.modelName || "";
                        root.settingModified();
                    }
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.leftMargin: Kirigami.Units.largeSpacing * 1.5
            text: ki18n.i18n("Note: if the selected display is disconnected, AOD will automatically fall back to the primary display.")
            font.pixelSize: 11
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
    }

    QQC2.Label {
        text: ki18n.i18n("Time & Energy Management:")
        color: Kirigami.Theme.textColor
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: true
        type: Kirigami.MessageType.Information
        text: ki18n.i18n("<b>Important note on idle timeouts:</b><br/><br/>• <b>Screen locking:</b> Determines after how many minutes of inactivity AOD activates.<br/>• <b>Screen turn-off (DPMS):</b> Cuts power to the display.<br/>For AOD to remain visible, this value must be <b>greater</b> than the screen lock timeout (e.g. 15-30 min or Never).")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.mediumSpacing

        QQC2.Button {
            text: ki18n.i18nc("@action:button", "KDE Screen Locker")
            icon.name: "preferences-desktop-user-password"
            Layout.fillWidth: true
            onClicked: root.runCommand("kcmshell6 kcm_screenlocker 2>/dev/null || systemsettings kcm_screenlocker")
        }

        QQC2.Button {
            text: ki18n.i18nc("@action:button", "Energy Saving (DPMS)")
            icon.name: "preferences-system-power-management"
            Layout.fillWidth: true
            onClicked: root.runCommand("kcmshell6 kcm_powerdevilprofilesconfig 2>/dev/null || systemsettings kcm_powerdevilprofilesconfig")
        }
    }
}
