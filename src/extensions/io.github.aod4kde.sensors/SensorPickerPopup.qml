import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.ki18n

QQC2.Popup {
    id: root
    property var availableSensors: []
    property var activeSensors: []
    signal sensorAdded(var sensorObj)
    signal requestReloadSensors()

    KI18nContext {
        id: ki18n
        translationDomain: "io.github.aod4kde.sensors"
    }

    parent: QQC2.Overlay.overlay
    width: Math.min(parent ? parent.width - 32 : 520, 540)
    height: Math.min(parent ? parent.height - 48 : 540, 560)
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    padding: Kirigami.Units.largeSpacing * 1.5
    modal: true
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    onAvailableSensorsChanged: {
        if (root.opened) {
            filterSensors(searchField.text);
        }
    }

    function openPicker() {
        searchField.text = "";
        if (!availableSensors || availableSensors.length === 0) {
            root.requestReloadSensors();
        }
        filterSensors("");
        root.open();
        searchField.forceActiveFocus();
    }

    function filterSensors(query) {
        filteredModel.clear();
        if (!availableSensors || availableSensors.length === 0) return;

        const q = (query || "").toLowerCase().trim();
        for (let i = 0; i < availableSensors.length; i++) {
            const s = availableSensors[i];
            if (!s || !s.id) continue;

            const sLabel = String(s.label || s.name || s.id);
            const sFull = String(s.fullName || s.name || sLabel);
            const sId = String(s.id);
            const sCat = String(s.category || sId.split("/")[0] || "").toUpperCase();
            const sUnit = String(s.unit || "");

            if (!q || sLabel.toLowerCase().indexOf(q) !== -1
                   || sFull.toLowerCase().indexOf(q) !== -1
                   || sId.toLowerCase().indexOf(q) !== -1
                   || sCat.toLowerCase().indexOf(q) !== -1) {
                let alreadyAdded = false;
                if (activeSensors) {
                    for (let j = 0; j < activeSensors.length; j++) {
                        if (activeSensors[j] && activeSensors[j].id === sId) {
                            alreadyAdded = true;
                            break;
                        }
                    }
                }
                if (!alreadyAdded) {
                    filteredModel.append({
                        "sensorId": sId,
                        "sensorLabel": sLabel,
                        "sensorFullName": sFull,
                        "sensorCategory": sCat,
                        "sensorUnit": sUnit
                    });
                }
            }
        }
    }

    ListModel {
        id: filteredModel
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.mediumSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                text: ki18n.i18nc("@title:window", "Choose a System Sensor")
                level: 3
                Layout.fillWidth: true
            }

            QQC2.ToolButton {
                icon.name: "window-close"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: ki18n.i18nc("@action:button", "Close")
                QQC2.ToolTip.visible: hovered
                onClicked: root.close()
            }
        }

        Kirigami.SearchField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: ki18n.i18nc("@info:placeholder", "Search sensor (e.g. CPU, GPU, RAM, network, battery)…")
            onTextChanged: root.filterSensors(text)
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit: false
            color: Kirigami.Theme.backgroundColor
            radius: 6
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
            clip: true

            QQC2.ScrollView {
                id: popupScrollView
                anchors.fill: parent
                anchors.margins: 2
                clip: true

                QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AlwaysOn
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                ListView {
                    id: sensorListView
                    model: filteredModel
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: QQC2.ItemDelegate {
                        required property string sensorId
                        required property string sensorLabel
                        required property string sensorFullName
                        required property string sensorCategory
                        required property string sensorUnit

                        width: popupScrollView.availableWidth

                        contentItem: ColumnLayout {
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                QQC2.Label {
                                    text: "[" + sensorCategory + "] " + sensorLabel
                                    font.bold: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                QQC2.Label {
                                    text: sensorUnit
                                    font.bold: true
                                    color: Kirigami.Theme.highlightColor
                                    visible: sensorUnit.length > 0
                                }
                            }

                            QQC2.Label {
                                text: sensorFullName + " (" + sensorId + ")"
                                font.pixelSize: 11
                                color: Kirigami.Theme.disabledTextColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        onClicked: {
                            root.sensorAdded({
                                "id": sensorId,
                                "label": sensorLabel,
                                "fullName": sensorFullName,
                                "unit": sensorUnit
                            });
                            root.close();
                        }
                    }
                }
            }

            QQC2.Label {
                anchors.centerIn: parent
                visible: filteredModel.count === 0
                text: (!root.availableSensors || root.availableSensors.length === 0)
                      ? ki18n.i18n("No sensors received from ksystemstats.")
                      : ki18n.i18n("No matching sensors found.")
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }
}

