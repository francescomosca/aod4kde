import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    // Standard properties injected by AOD host
    property real uiScale: 1.0
    property var extensionConfig: ({})
    property var aodConfig: ({})
    property bool aodVisible: true

    function dp(val) {
        return Math.round(val * (uiScale > 0 ? uiScale : 1.0));
    }

    Layout.alignment: Qt.AlignHCenter
    spacing: dp(6)

    Text {
        text: "Hello World"
        color: "#ffffff"
        font.pixelSize: root.dp(14)
        font.bold: true
        renderType: Text.NativeRendering
    }
}

