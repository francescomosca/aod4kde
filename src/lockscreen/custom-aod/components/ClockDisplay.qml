import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property var dateTime: new Date()
    property bool showDate: true
    property string clockFont: "system"
    property bool useCustomDateFormat: false
    property string customDateFormat: ""

    readonly property bool isCustomClockFont: root.clockFont && root.clockFont !== "system"

    spacing: Units.dp(14)
    Layout.alignment: Qt.AlignHCenter

    // ORA
    Text {
        text: Qt.formatTime(root.dateTime, "hh:mm")
        font.pixelSize: root.clockFont === "Press Start 2P" ? Units.dp(56) : Units.dp(84)
        font.weight: root.isCustomClockFont ? Font.Normal : Font.Thin
        font.family: root.isCustomClockFont ? root.clockFont : ""
        color: "#e6e6e6"
        renderType: Text.NativeRendering
        antialiasing: true
        font.hintingPreference: Font.PreferFullHinting
        Layout.alignment: Qt.AlignHCenter
    }

    // DATA
    Text {
        visible: root.showDate
        text: {
            if (!root.dateTime) return "";
            if (root.useCustomDateFormat && root.customDateFormat && root.customDateFormat.trim() !== "") {
                try {
                    return root.dateTime.toLocaleDateString(Qt.locale(), root.customDateFormat.trim());
                } catch (e) {
                    // Fallback to standard locale date on formatting failure
                }
            }
            return root.dateTime.toLocaleDateString(Qt.locale(), Locale.LongFormat);
        }
        font.pixelSize: Units.dp(18)
        font.weight: Font.Light
        color: "#aaaaaa"
        renderType: Text.NativeRendering
        antialiasing: true
        font.hintingPreference: Font.PreferFullHinting
        Layout.alignment: Qt.AlignHCenter
    }

    Item {
        Layout.preferredHeight: Units.dp(18)
        visible: root.showDate
    }
}
