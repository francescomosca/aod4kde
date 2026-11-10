import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.ki18n

ColumnLayout {
    id: root
    spacing: Kirigami.Units.smallSpacing

    required property var config
    signal settingModified()

    KI18nContext {
        id: ki18n
        translationDomain: "aod4kde"
    }

    function fontPath(filename) {
        const base = Qt.resolvedUrl(".").toString();
        if (base.indexOf("/src/settings/components") !== -1) {
            return Qt.resolvedUrl("../../../assets/fonts/" + filename);
        }
        if (base.indexOf("/settings/components") !== -1) {
            return Qt.resolvedUrl("../../assets/fonts/" + filename);
        }
        return Qt.resolvedUrl("../assets/fonts/" + filename);
    }

    // Font loading for preview cards
    FontLoader { id: fontOrbitron; source: fontPath("Orbitron.ttf") }
    FontLoader { id: fontRampart; source: fontPath("RampartOne.ttf") }
    FontLoader { id: fontRubik; source: fontPath("RubikScribble.ttf") }
    FontLoader { id: fontPressStart; source: fontPath("PressStart2P.ttf") }
    FontLoader { id: fontInstrument; source: fontPath("InstrumentSerif.ttf") }

    property string selectedClockFont: "system"

    readonly property var fontOptions: [
        { id: "system", name: ki18n.i18nc("@item:inlistbox", "System Font"), family: "", previewWeight: Font.Thin, previewSize: 26 },
        { id: "Orbitron", name: "Orbitron", family: fontOrbitron.name || "Orbitron", previewWeight: Font.Medium, previewSize: 24 },
        { id: "Rampart One", name: "Rampart One", family: fontRampart.name || "Rampart One", previewWeight: Font.Normal, previewSize: 24 },
        { id: "Rubik Scribble", name: "Rubik Scribble", family: fontRubik.name || "Rubik Scribble", previewWeight: Font.Normal, previewSize: 22 },
        { id: "Press Start 2P", name: "Press Start 2P", family: fontPressStart.name || "Press Start 2P", previewWeight: Font.Normal, previewSize: 14 },
        { id: "Instrument Serif", name: "Instrument Serif", family: fontInstrument.name || "Instrument Serif", previewWeight: Font.Normal, previewSize: 26 }
    ]

    readonly property var currentFontOption: {
        for (let i = 0; i < fontOptions.length; i++) {
            let opt = fontOptions[i];
            if (opt.id === "system") {
                if (!root.selectedClockFont || root.selectedClockFont === "system" || root.selectedClockFont === "Noto Sans") {
                    return opt;
                }
            } else if (opt.id === root.selectedClockFont) {
                return opt;
            }
        }
        return fontOptions[0];
    }

    function syncFromConfig() {
        if (!root.config) return;
        selectedClockFont = root.config.clockFont || "system";
    }

    function openFontSheet() {
        if (!fontSheetLoader.active) {
            fontSheetLoader.active = true;
        } else if (fontSheetLoader.item) {
            fontSheetLoader.item.open();
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 3
        Layout.bottomMargin: Kirigami.Units.smallSpacing

        QQC2.Label {
            text: ki18n.i18n("Clock Style:")
            color: Kirigami.Theme.textColor
        }

        QQC2.Label {
            text: ki18n.i18n("Select the clock typography.")
            font.pixelSize: 11
            color: Kirigami.Theme.disabledTextColor
        }
    }

    // Preview of currently selected font with button to open modal
    RowLayout {
        spacing: Kirigami.Units.largeSpacing

        Rectangle {
            id: currentCard
            Layout.preferredWidth: 100
            Layout.preferredHeight: 100
            radius: 10
            color: "#000000"
            border.width: 2
            border.color: Kirigami.Theme.highlightColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing * 1.5
                spacing: 2

                Item { Layout.fillHeight: true }

                QQC2.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "12:00"
                    font.pixelSize: root.currentFontOption.previewSize || 24
                    font.family: root.currentFontOption.family
                    font.weight: root.currentFontOption.previewWeight
                    color: "#FFFFFF"
                }

                Item { Layout.fillHeight: true }

                QQC2.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.currentFontOption.name
                    font.bold: true
                    font.pixelSize: 11
                    color: "#EEEEEE"
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openFontSheet()
            }
        }

        QQC2.Button {
            Layout.alignment: Qt.AlignVCenter
            text: ki18n.i18nc("@action:button", "Choose…")
            icon.name: "preferences-desktop-font"
            onClicked: root.openFontSheet()
        }
    }

    // On-demand modal/sheet with grid view to select font
    Loader {
        id: fontSheetLoader
        active: false
        onLoaded: item.open()

        sourceComponent: Component {
            Kirigami.OverlaySheet {
                id: fontSheet
                parent: QQC2.Overlay.overlay
                title: ki18n.i18nc("@title:window", "Choose a Style")

                header: Kirigami.Heading {
                    text: ki18n.i18nc("@title:window", "Choose a Style")
                    level: 2
                }

                Item {
                    implicitWidth: fontGrid.cellWidth * 3 + Kirigami.Units.largeSpacing * 2
                    implicitHeight: fontGrid.cellHeight * Math.ceil(root.fontOptions.length / 3)

                    GridView {
                        id: fontGrid
                        anchors.fill: parent
                        cellWidth: 120
                        cellHeight: 120
                        clip: true
                        interactive: false
                        model: root.fontOptions

                        delegate: Item {
                            id: cellItem
                            required property var modelData
                            width: fontGrid.cellWidth
                            height: fontGrid.cellHeight

                            Rectangle {
                                id: fontCard
                                width: 106
                                height: 106
                                anchors.centerIn: parent
                                radius: 10

                                readonly property bool isSelected: {
                                    if (cellItem.modelData.id === "system") {
                                        return !root.selectedClockFont || root.selectedClockFont === "system" || root.selectedClockFont === "Noto Sans";
                                    }
                                    return root.selectedClockFont === cellItem.modelData.id;
                                }

                                color: "#000000"

                                border.width: isSelected ? 2 : 1
                                border.color: isSelected
                                              ? Kirigami.Theme.highlightColor
                                              : (cardMouse.containsMouse ? Qt.alpha(Kirigami.Theme.textColor, 0.3) : Qt.alpha(Kirigami.Theme.textColor, 0.12))

                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing * 1.5
                                    spacing: 2

                                    Item { Layout.fillHeight: true }

                                    QQC2.Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "12:00"
                                        font.pixelSize: cellItem.modelData.previewSize || 24
                                        font.family: cellItem.modelData.family
                                        font.weight: cellItem.modelData.previewWeight
                                        color: "#FFFFFF"
                                    }

                                    Item { Layout.fillHeight: true }

                                    QQC2.Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: cellItem.modelData.name
                                        font.bold: fontCard.isSelected
                                        font.pixelSize: 11
                                        opacity: 0.5
                                        color: fontCard.isSelected ? '#EEEEEE' : '#CCCCCC'
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedClockFont = cellItem.modelData.id;
                                        root.config.clockFont = cellItem.modelData.id;
                                        root.settingModified();
                                        fontSheet.close();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
