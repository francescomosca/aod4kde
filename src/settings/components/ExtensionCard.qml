import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.ki18n

Kirigami.AbstractCard {
    id: root

    property string title: ""
    property string description: ""
    property string iconName: ""
    property string version: ""
    property string author: ""
    property bool isBuiltIn: false
    property bool extensionEnabled: false
    property bool daemonFailed: false
    property bool hasSettings: false
    property bool expanded: false

    property string settingsQmlUrl: ""
    property var extensionConfig: ({})
    property var appWindow: null

    property ListView listView: null
    property Item dragListItem: root
    property bool showDragHandle: true

    signal extensionToggled(bool newState)
    signal settingModified()
    signal moveRequested(int oldIndex, int newIndex)
    signal dropped(int oldIndex, int newIndex)
    signal removeRequested()
    signal retryDaemonRequested()

    default property alias bodyContent: customBodyLayout.data

    showClickFeedback: false
    hoverEnabled: false

    KI18nContext {
        id: ki18n
        translationDomain: "aod4kde"
    }

    contentItem: ColumnLayout {
        spacing: 0

        // HEADER
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            // Drag handle for reordering
            Kirigami.ListItemDragHandle {
                id: dragHandle
                visible: root.showDragHandle && root.extensionEnabled
                listItem: root.dragListItem
                listView: root.listView
                Layout.alignment: Qt.AlignVCenter
                onMoveRequested: (oldIndex, newIndex) => root.moveRequested(oldIndex, newIndex)
                onDropped: (oldIndex, newIndex) => root.dropped(oldIndex, newIndex)
            }

            // Badge Icona
            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 10
                color: Qt.alpha(Kirigami.Theme.disabledTextColor, 0.01)
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.disabledTextColor, 0.25)

                Kirigami.Icon {
                    anchors.centerIn: parent
                    implicitWidth: 24
                    implicitHeight: 24
                    source: root.iconName || "preferences-plugin"
                    color: Kirigami.Theme.disabledTextColor
                }
            }

            // Titolo + Badges + Descrizione
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: root.title
                        font.bold: true
                        font.pixelSize: 14
                    }

                    // Badge Tipo (Sistema vs Community)
                    Rectangle {
                        visible: root.isBuiltIn
                        radius: 4
                        implicitWidth: typeLabel.implicitWidth + 8
                        implicitHeight: typeLabel.implicitHeight + 4
                        color: root.isBuiltIn
                               ? Qt.alpha(Kirigami.Theme.highlightColor, 0.18)
                               : Qt.alpha(Kirigami.Theme.neutralTextColor, 0.18)

                        QQC2.Label {
                            id: typeLabel
                            anchors.centerIn: parent
                            text: ki18n.i18nc("@label", "Built-in")
                            font.pixelSize: 9
                            font.bold: true
                            color: root.isBuiltIn
                                   ? Kirigami.Theme.highlightColor
                                   : Kirigami.Theme.textColor
                        }
                    }

                    // Status Badge (Active / Disabled)
                    Rectangle {
                        radius: 4
                        implicitWidth: statusText.implicitWidth + 10
                        implicitHeight: statusText.implicitHeight + 4
                        color: root.extensionEnabled
                               ? Qt.alpha(Kirigami.Theme.positiveTextColor, 0.15)
                               : Qt.alpha(Kirigami.Theme.disabledTextColor, 0.15)

                        QQC2.Label {
                            id: statusText
                            anchors.centerIn: parent
                            text: root.extensionEnabled
                                  ? ki18n.i18nc("@label", "Active")
                                  : ki18n.i18nc("@label", "Disabled")
                            font.pixelSize: 10
                            font.bold: true
                            color: root.extensionEnabled
                                   ? Kirigami.Theme.positiveTextColor
                                   : Kirigami.Theme.disabledTextColor
                        }
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: root.description
                    font.pixelSize: 11
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                }

                // Author row for third-party / community extensions
                RowLayout {
                    Layout.fillWidth: true
                    visible: !root.isBuiltIn && root.author.length > 0
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        implicitWidth: 14
                        implicitHeight: 14
                        source: "user"
                        color: Kirigami.Theme.disabledTextColor
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: root.author
                        font.pixelSize: 11
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                }
            }

            // Accordion Button (visible if there are settings)
            QQC2.ToolButton {
                visible: root.hasSettings || root.settingsQmlUrl.length > 0
                icon.name: root.expanded ? "arrow-up" : "arrow-down"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: root.expanded ? ki18n.i18nc("@info:tooltip", "Collapse settings") : ki18n.i18nc("@info:tooltip", "Expand settings")
                QQC2.ToolTip.visible: hovered
                onClicked: root.expanded = !root.expanded
            }

            // Active/Disabled CheckBox
            QQC2.CheckBox {
                checked: root.extensionEnabled
                onToggled: root.extensionToggled(checked)
            }

            // Remove Community Extension Button
            QQC2.ToolButton {
                visible: !root.isBuiltIn
                icon.name: "edit-delete"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: ki18n.i18nc("@info:tooltip", "Remove extension")
                QQC2.ToolTip.visible: hovered
                onClicked: root.removeRequested()
            }

        }

        // Warning banner for daemons that crashed repeatedly or failed to start
        Kirigami.InlineMessage {
            id: daemonCrashWarning
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            type: Kirigami.MessageType.Warning
            visible: root.daemonFailed && root.extensionEnabled
            text: ki18n.i18n("The background service for this extension failed to start or crashed repeatedly and was stopped.")
            showCloseButton: false
            actions: [
                Kirigami.Action {
                    text: ki18n.i18nc("@action:button", "Retry")
                    icon.name: "view-refresh"
                    onTriggered: root.retryDaemonRequested()
                }
            ]
        }

        // SEPARATOR & ACCORDION BODY
        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            visible: (root.hasSettings || root.settingsQmlUrl.length > 0) && root.expanded
        }

        ColumnLayout {
            id: bodyLayout
            Layout.fillWidth: true
            visible: (root.hasSettings || root.settingsQmlUrl.length > 0) && root.expanded
            spacing: Kirigami.Units.mediumSpacing

            // Error banner protected against broken plugin SettingsWidget.qml
            Kirigami.InlineMessage {
                id: errorMessage
                Layout.fillWidth: true
                type: Kirigami.MessageType.Error
                visible: settingsLoader.status === Loader.Error
                text: ki18n.i18n("Unable to load extension settings: the QML file contains errors.")
                showCloseButton: false
            }

            // Isolated loader to dynamically load SettingsWidget.qml
            Loader {
                id: settingsLoader
                Layout.fillWidth: true
                visible: root.settingsQmlUrl.length > 0 && status === Loader.Ready
                source: (root.expanded && root.settingsQmlUrl.length > 0) ? root.settingsQmlUrl : ""

                onLoaded: {
                    if (item) {
                        try {
                            if (item.hasOwnProperty("extensionConfig")) {
                                item.extensionConfig = root.extensionConfig;
                            }
                            if (item.hasOwnProperty("appWindow")) {
                                item.appWindow = root.appWindow;
                            }
                            if (item.settingModified) {
                                item.settingModified.connect(() => root.settingModified());
                            }
                        } catch(e) {
                            console.error("Error initializing SettingsWidget:", e);
                        }
                    }
                }
            }

            // Custom fallback layout if used directly
            ColumnLayout {
                id: customBodyLayout
                Layout.fillWidth: true
                visible: root.settingsQmlUrl.length === 0
                spacing: Kirigami.Units.mediumSpacing
            }
        }
    }
}
