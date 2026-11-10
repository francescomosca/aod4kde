import QtQuick
import QtQuick.Layouts
import org.kde.ksysguard.sensors as Sensors

RowLayout {
    id: root

    // Properties passed by AOD host AodClockStats
    property real uiScale: 1.0
    property var extensionConfig: ({})
    property var aodConfig: ({})
    property bool aodVisible: true

    function dp(val) {
        return Math.round(val * (uiScale > 0 ? uiScale : 1.0));
    }

    readonly property bool coloredSensors: extensionConfig ? (extensionConfig.coloredSensors !== false) : true
    readonly property var sensorList: (extensionConfig && extensionConfig.sensors) ? extensionConfig.sensors : []

    visible: sensorList && sensorList.length > 0
    Layout.alignment: Qt.AlignHCenter
    spacing: dp(24)

    function getSensorColor(sensorId, valNumber) {
        if (!coloredSensors) return "#cccccc";
        const sid = (sensorId || "").toLowerCase();
        if (sid.indexOf("cpu") !== -1 && sid.indexOf("usage") !== -1) return "#00d4aa";
        if (sid.indexOf("temp") !== -1 || sid.indexOf("temperature") !== -1) {
            const val = Number(valNumber);
            if (!isNaN(val)) {
                return val >= 80 ? "#ff5555" : (val >= 70 ? "#ffaa00" : "#00aaff");
            }
            return "#00aaff";
        }
        if (sid.indexOf("memory") !== -1) return "#ffb300";
        if (sid.indexOf("network") !== -1) return "#ab47bc";
        if (sid.indexOf("power") !== -1) return "#26a69a";
        return "#dddddd";
    }

    function cleanUnit(u) {
        if (!u) return "";
        return u.toString().replace(/Â/g, "").trim();
    }

    Repeater {
        id: sensorsRepeater
        model: root.sensorList

        delegate: RowLayout {
            id: sensorItem
            required property int index
            required property var modelData
            spacing: root.dp(8)

            Sensors.Sensor {
                id: ksensor
                sensorId: sensorItem.modelData.id || ""
                enabled: root.aodVisible
                updateRateLimit: 2000
            }

            Text {
                text: sensorItem.modelData.label || ksensor.shortName || ksensor.name || ""
                font.pixelSize: root.dp(13)
                font.weight: Font.DemiBold
                color: root.getSensorColor(sensorItem.modelData.id, ksensor.value)
                renderType: Text.NativeRendering
                antialiasing: true
            }

            Text {
                text: {
                    if (ksensor.status === Sensors.Sensor.Ready) {
                        const unitStr = root.cleanUnit(sensorItem.modelData.unit);
                        if (unitStr) {
                            const num = Math.round(Number(ksensor.value));
                            return (!isNaN(num) ? num : ksensor.value) + (unitStr === "%" ? "%" : " " + unitStr);
                        }
                        return ksensor.formattedValue;
                    }
                    return "...";
                }
                font.pixelSize: root.dp(15)
                font.weight: Font.Normal
                color: root.coloredSensors ? "#dddddd" : "#cccccc"
                renderType: Text.NativeRendering
                antialiasing: true
            }

            Rectangle {
                visible: index < sensorsRepeater.count - 1
                width: Math.max(1, root.dp(1))
                height: root.dp(14)
                color: "#333333"
                Layout.leftMargin: root.dp(12)
            }
        }
    }
}

