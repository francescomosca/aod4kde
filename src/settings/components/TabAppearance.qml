import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.ki18n

ColumnLayout {
    id: root
    spacing: Kirigami.Units.largeSpacing

    required property var config
    property bool hasBattery: true
    signal settingModified()

    KI18nContext {
        id: ki18n
        translationDomain: "aod4kde"
    }

    function syncFromConfig() {
        if (!root.config) return;
        dateSwitch.checked = root.config.showDate !== false;
        customDateFormatSwitch.checked = !!root.config.useCustomDateFormat;
        customDateFormatField.text = root.config.customDateFormat || "";
        batterySwitch.checked = root.hasBattery && (root.config.showBattery !== false);
        showBackgroundSwitch.checked = !!root.config.showBackground;

        bgOpacitySlider.value = (root.config.backgroundOpacity !== undefined) ? root.config.backgroundOpacity : 20;

        scaleSlider.value = (root.config.scale !== undefined) ? root.config.scale : 100;

        clockFontPicker.syncFromConfig();
    }


    ClockFontPicker {
        id: clockFontPicker
        Layout.fillWidth: true
        config: root.config
        onSettingModified: root.settingModified()
    }

    Kirigami.Separator {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
    }

    QQC2.Label {
        text: ki18n.i18n("AOD elements:")
        color: Kirigami.Theme.textColor
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.mediumSpacing

        QQC2.CheckBox {
            id: dateSwitch
            Layout.fillWidth: true
            text: ki18n.i18n("Show date")
            onToggled: {
                root.config.showDate = checked;
                root.settingModified();
            }
        }

        // Custom date format sub-option
        ColumnLayout {
            visible: dateSwitch.checked
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing * 1.5
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.mediumSpacing

                QQC2.CheckBox {
                    id: customDateFormatSwitch
                    text: ki18n.i18n("Custom date format:")
                    onToggled: {
                        root.config.useCustomDateFormat = checked;
                        if (checked && (!root.config.customDateFormat || root.config.customDateFormat.trim() === "")) {
                            root.config.customDateFormat = "ddd, d MMMM";
                            customDateFormatField.text = root.config.customDateFormat;
                        }
                        root.settingModified();
                    }
                }

                QQC2.TextField {
                    id: customDateFormatField
                    Layout.fillWidth: true
                    enabled: customDateFormatSwitch.checked
                    placeholderText: "ddd, d MMMM"
                    onTextEdited: {
                        root.config.customDateFormat = text;
                        root.settingModified();
                    }
                }
            }

            QQC2.Label {
                visible: customDateFormatSwitch.checked
                text: {
                    const fmt = (customDateFormatField.text && customDateFormatField.text.trim()) || customDateFormatField.placeholderText;
                    try {
                        return ki18n.i18n("Preview: %1", (new Date()).toLocaleDateString(Qt.locale(), fmt));
                    } catch (e) {
                        return "";
                    }
                }
                font.pixelSize: 11
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
            }
        }

        Item {
            Layout.fillWidth: true
            implicitWidth: batterySwitch.implicitWidth
            implicitHeight: batterySwitch.implicitHeight

            QQC2.CheckBox {
                id: batterySwitch
                anchors.fill: parent
                enabled: root.hasBattery
                text: ki18n.i18n("Show battery status and percentage")
                onToggled: {
                    root.config.showBattery = checked;
                    root.settingModified();
                }
            }

            HoverHandler {
                id: batteryHover
            }

            QQC2.ToolTip.text: ki18n.i18nc("@info:tooltip", "No battery detected")
            QQC2.ToolTip.visible: !root.hasBattery && batteryHover.hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        QQC2.CheckBox {
            id: showBackgroundSwitch
            Layout.fillWidth: true
            text: ki18n.i18n("Show lockscreen background")
            onToggled: {
                root.config.showBackground = checked;
                root.settingModified();
            }
        }

        // Indented sub-option for background opacity
        ColumnLayout {
            visible: showBackgroundSwitch.checked
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing * 1.5
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                QQC2.Label {
                    text: ki18n.i18n("Background opacity:")
                    Layout.fillWidth: true
                }

                QQC2.Label {
                    text: Math.round(bgOpacitySlider.value) + "%"
                    font.bold: true
                    color: Kirigami.Theme.highlightColor
                }
            }

            QQC2.Slider {
                id: bgOpacitySlider
                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: 5
                snapMode: QQC2.Slider.SnapAlways
                value: 20
                onMoved: {
                    root.config.backgroundOpacity = Math.round(value);
                    root.settingModified();
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: ki18n.i18n("0% = pure OLED black, 100% = full brightness")
                    font.pixelSize: 11
                    color: Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                QQC2.Label {
                    visible: bgOpacitySlider.value > 33
                    text: ki18n.i18n("⚠️ Not recommended on OLED")
                    font.pixelSize: 11
                    font.bold: true
                    color: Kirigami.Theme.neutralTextColor
                }
            }
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            QQC2.Label {
                text: ki18n.i18n("Interface scale:")
                Layout.fillWidth: true
            }

            QQC2.Label {
                text: Math.round(scaleSlider.value) + "%"
                font.bold: true
                color: Kirigami.Theme.highlightColor
            }
        }

        QQC2.Slider {
            id: scaleSlider
            Layout.fillWidth: true
            from: 50
            to: 250
            stepSize: 25
            snapMode: QQC2.Slider.SnapAlways
            value: 100
            onMoved: {
                root.config.scale = Math.round(value);
                root.settingModified();
            }
        }

        QQC2.Label {
            text: ki18n.i18n("Adjust AOD size (min 50%, max 250%)")
            font.pixelSize: 11
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }
}
