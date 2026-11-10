import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.battery

RowLayout {
    id: root

    // Native Plasma 6 battery model (C++ event-driven)
    BatteryControlModel {
        id: batteryControl
    }

    property int batteryPercent: batteryControl.percent
    property bool pluggedIn: batteryControl.pluggedIn
    property int chargeState: batteryControl.state // 0: NoCharge, 1: Charging, 2: Discharging, 3: FullyCharged
    property int chargeStopThreshold: batteryControl.chargeStopThreshold

    spacing: Units.dp(6)

    // Active charging condition
    readonly property bool isCharging: chargeState === 1

    // Standard KDE Breeze battery icon (battery-XXX or battery-XXX-charging)
    Kirigami.Icon {
        id: batIcon
        width: Units.dp(16)
        height: Units.dp(16)
        Layout.preferredWidth: Units.dp(16)
        Layout.preferredHeight: Units.dp(16)
        source: {
            const p = Math.min(100, Math.max(0, root.batteryPercent));
            let name;
            if (p >= 95) name = "battery-100";
            else if (p >= 85) name = "battery-090";
            else if (p >= 75) name = "battery-080";
            else if (p >= 65) name = "battery-070";
            else if (p >= 55) name = "battery-060";
            else if (p >= 45) name = "battery-050";
            else if (p >= 35) name = "battery-040";
            else if (p >= 25) name = "battery-030";
            else if (p >= 15) name = "battery-020";
            else if (p > 5)   name = "battery-010";
            else              name = "battery-000";

            // If plugged into power or charging, use KDE charging variant with lightning bolt
            if (root.pluggedIn || root.isCharging) {
                name += "-charging";
            }
            return name;
        }
    }

    // Numeric percentage (e.g. 82%)
    Text {
        text: Math.round(Number(root.batteryPercent)) + "%"
        font.pixelSize: Units.dp(13)
        font.weight: Font.Normal
        color: {
            if (root.pluggedIn) return "#cccccc";
            if (root.batteryPercent <= 15) return "#ff5555";
            if (root.batteryPercent <= 25) return "#ffaa00";
            return "#cccccc";
        }
        renderType: Text.NativeRendering
        antialiasing: true
    }
}
