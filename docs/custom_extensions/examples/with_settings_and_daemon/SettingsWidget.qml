import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: Kirigami.Units.mediumSpacing

    // Standard properties and signals required by aod-settings
    property var extensionConfig: ({})
    property var appWindow: null
    signal settingModified()

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.mediumSpacing

        QQC2.Label {
            text: "Label prefix:"
        }

        QQC2.TextField {
            Layout.fillWidth: true
            text: root.extensionConfig ? (root.extensionConfig.prefix || "") : ""
            placeholderText: "e.g. System:"
            onTextEdited: {
                if (!root.extensionConfig) root.extensionConfig = {};
                root.extensionConfig.prefix = text;
                root.settingModified();
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.mediumSpacing

        QQC2.Label {
            text: "Text color (HEX):"
        }

        QQC2.TextField {
            Layout.fillWidth: true
            text: root.extensionConfig ? (root.extensionConfig.color || "") : ""
            placeholderText: "e.g. #00ffcc"
            onTextEdited: {
                if (!root.extensionConfig) root.extensionConfig = {};
                root.extensionConfig.color = text;
                root.settingModified();
            }
        }
    }
}

