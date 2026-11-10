import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import org.kde.ki18n

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: Kirigami.Units.mediumSpacing

    KI18nContext {
        id: ki18n
        translationDomain: "io.github.aod4kde.sensors"
    }

    property var extensionConfig: ({})
    property var appWindow: null
    signal settingModified()

    property var availableSensorsList: []

    ListModel {
        id: sensorsModel
    }

    P5Support.DataSource {
        id: sensorsHelperSource
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            const out = (data["stdout"] || "").trim();
            if (out.length > 0) {
                try {
                    const parsedSensors = JSON.parse(out);
                    if (Array.isArray(parsedSensors)) {
                        root.availableSensorsList = parsedSensors;
                    }
                } catch(e) {
                    console.log("Errore parsing lista sensori:", e);
                }
            }
            sensorsHelperSource.disconnectSource(sourceName);
        }
    }

    function reloadAvailableSensors() {
        const localExtDir = Qt.resolvedUrl(".").toString().replace("file://", "");
        const localBin = localExtDir + "/bin/aod-ext-sensors";
        sensorsHelperSource.connectSource(
            "if [ -x \"" + localBin + "\" ]; then \"" + localBin + "\"; " +
            "elif [ -x ~/.local/share/aod4kde/extensions/io.github.aod4kde.sensors/bin/aod-ext-sensors ]; then ~/.local/share/aod4kde/extensions/io.github.aod4kde.sensors/bin/aod-ext-sensors; " +
            "elif [ -x /usr/local/share/aod4kde/extensions/io.github.aod4kde.sensors/bin/aod-ext-sensors ]; then /usr/local/share/aod4kde/extensions/io.github.aod4kde.sensors/bin/aod-ext-sensors; " +
            "elif [ -x /usr/share/aod4kde/extensions/io.github.aod4kde.sensors/bin/aod-ext-sensors ]; then /usr/share/aod4kde/extensions/io.github.aod4kde.sensors/bin/aod-ext-sensors; fi"
        );
    }

    function ensureDefaults() {
        if (!root.extensionConfig) root.extensionConfig = {};
        let modified = false;
        if (root.extensionConfig.coloredSensors === undefined) {
            root.extensionConfig.coloredSensors = true;
            modified = true;
        }
        if (root.extensionConfig.sensors === undefined) {
            root.extensionConfig.sensors = [
                { "id": "cpu/all/usage", "label": "CPU", "unit": "%" }
            ];
            modified = true;
        }
        return modified;
    }

    function syncModel() {
        sensorsModel.clear();
        ensureDefaults();
        const list = root.extensionConfig.sensors || [];
        for (let i = 0; i < list.length; i++) {
            sensorsModel.append({
                "sensorId": list[i].id || "",
                "sensorLabel": list[i].label || "",
                "sensorUnit": list[i].unit || ""
            });
        }
    }

    onExtensionConfigChanged: syncModel()
    Component.onCompleted: {
        syncModel();
        reloadAvailableSensors();
    }

    QQC2.CheckBox {
        id: colorSwitch
        Layout.fillWidth: true
        text: ki18n.i18n("Dynamic color for sensors (based on value)")
        checked: root.extensionConfig ? (root.extensionConfig.coloredSensors !== false) : true
        onToggled: {
            if (!root.extensionConfig) root.extensionConfig = {};
            root.extensionConfig.coloredSensors = checked;
            root.settingModified();
            if (root.appWindow && root.appWindow.markChanged) {
                root.appWindow.markChanged();
            }
        }
    }

    QQC2.Label {
        text: ki18n.i18n("Active sensors:")
        color: Kirigami.Theme.textColor
    }

    QQC2.Label {
        visible: sensorsModel.count === 0
        text: ki18n.i18n("No sensors configured.")
        color: Kirigami.Theme.disabledTextColor
        font.italic: true
    }

    Repeater {
        model: sensorsModel
        delegate: Kirigami.AbstractCard {
            id: sensorCardDelegate
            required property int index
            required property string sensorId
            required property string sensorLabel
            required property string sensorUnit

            Layout.fillWidth: true
            showClickFeedback: false
            hoverEnabled: false

            contentItem: RowLayout {
                spacing: Kirigami.Units.mediumSpacing

                QQC2.TextField {
                    id: labelEditField
                    text: sensorCardDelegate.sensorLabel
                    Layout.preferredWidth: 120
                    font.bold: true
                    placeholderText: ki18n.i18nc("@info:placeholder", "Label")
                    onEditingFinished: {
                        const clean = text.trim();
                        if (clean.length > 0) {
                            text = clean;
                            if (clean !== sensorCardDelegate.sensorLabel) {
                                if (root.extensionConfig && root.extensionConfig.sensors && root.extensionConfig.sensors[sensorCardDelegate.index]) {
                                    root.extensionConfig.sensors[sensorCardDelegate.index].label = clean;
                                    sensorsModel.setProperty(sensorCardDelegate.index, "sensorLabel", clean);
                                    root.settingModified();
                                    if (root.appWindow && root.appWindow.markChanged) {
                                        root.appWindow.markChanged();
                                    }
                                }
                            }
                        } else {
                            text = sensorCardDelegate.sensorLabel;
                        }
                    }
                }

                QQC2.Label {
                    visible: sensorCardDelegate.sensorUnit.length > 0
                    text: "(" + sensorCardDelegate.sensorUnit + ")"
                    font.pixelSize: 12
                    font.bold: true
                    color: Kirigami.Theme.highlightColor
                }

                QQC2.Label {
                    text: sensorCardDelegate.sensorId
                    color: Kirigami.Theme.disabledTextColor
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }

                QQC2.Button {
                    icon.name: "edit-delete-remove"
                    text: ki18n.i18nc("@action:button", "Remove")
                    flat: true
                    QQC2.ToolTip.text: ki18n.i18nc("@info:tooltip", "Remove sensor from AOD")
                    QQC2.ToolTip.visible: hovered
                    onClicked: {
                        if (root.extensionConfig && root.extensionConfig.sensors) {
                            const targetIdx = sensorCardDelegate.index;
                            if (targetIdx >= 0 && targetIdx < root.extensionConfig.sensors.length) {
                                root.extensionConfig.sensors.splice(targetIdx, 1);
                                root.settingModified();
                                if (root.appWindow && root.appWindow.markChanged) {
                                    root.appWindow.markChanged();
                                }
                                sensorsModel.remove(targetIdx);
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.mediumSpacing

        QQC2.Button {
            Layout.fillWidth: true
            icon.name: "list-add"
            text: ki18n.i18nc("@action:button", "Add sensor…")
            onClicked: {
                sensorPickerPopup.openPicker();
            }
        }

        QQC2.Button {
            Layout.fillWidth: true
            text: ki18n.i18nc("@action:button", "Reset to defaults")
            icon.name: "edit-undo"
            onClicked: {
                if (!root.extensionConfig) root.extensionConfig = {};
                root.extensionConfig.coloredSensors = true;
                colorSwitch.checked = true;
                root.extensionConfig.sensors = [
                    { "id": "cpu/all/usage", "label": "CPU", "unit": "%" }
                ];
                root.syncModel();
                root.settingModified();
                if (root.appWindow && root.appWindow.markChanged) {
                    root.appWindow.markChanged();
                }
            }
        }
    }

    SensorPickerPopup {
        id: sensorPickerPopup
        availableSensors: root.availableSensorsList
        activeSensors: (root.extensionConfig && root.extensionConfig.sensors) ? root.extensionConfig.sensors : []
        onRequestReloadSensors: root.reloadAvailableSensors()
        onSensorAdded: (s) => {
            if (!root.extensionConfig) root.extensionConfig = {};
            if (!root.extensionConfig.sensors) root.extensionConfig.sensors = [];
            root.extensionConfig.sensors.push({
                "id": s.id,
                "label": s.label,
                "fullName": s.fullName || "",
                "unit": s.unit || ""
            });
            root.syncModel();
            root.settingModified();
            if (root.appWindow && root.appWindow.markChanged) {
                root.appWindow.markChanged();
            }
        }
    }
}
