import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.ki18n

ColumnLayout {
    id: root
    spacing: Kirigami.Units.largeSpacing

    required property var config
    property var extensionsList: []
    property var appWindow: null

    signal settingModified()
    signal requestReloadExtensions()
    signal requestRemoveExtension(string extensionId, bool keepSettings)

    KI18nContext {
        id: ki18n
        translationDomain: "aod4kde"
    }

    function getOrphanedExtensionIds() {
        const installedIds = (root.extensionsList || []).map(e => e.id);
        const activeConfigIds = (root.config && root.config.extensions) ? Object.keys(root.config.extensions) : [];
        let savedConfigIds = [];
        if (root.appWindow && root.appWindow.savedConfigSnapshot) {
            try {
                const snap = JSON.parse(root.appWindow.savedConfigSnapshot);
                if (snap && snap.extensions) {
                    savedConfigIds = Object.keys(snap.extensions);
                }
            } catch(e) {}
        }
        const allIds = activeConfigIds.concat(savedConfigIds.filter(id => activeConfigIds.indexOf(id) === -1));
        return allIds.filter(id => installedIds.indexOf(id) === -1);
    }

    function restoreOrphanData(id, backupEntry) {
        installedExtensionsList.ensureConfigStructure();
        let snap = null;
        if (root.appWindow && root.appWindow.savedConfigSnapshot) {
            try {
                snap = JSON.parse(root.appWindow.savedConfigSnapshot);
            } catch(e) {}
        }
        const entryToRestore = (snap && snap.extensions && snap.extensions[id])
            ? snap.extensions[id]
            : (backupEntry || { "enabled": false, "config": {} });

        if (snap && snap.extensions) {
            let newExts = {};
            const snapKeys = Object.keys(snap.extensions);
            for (let i = 0; i < snapKeys.length; i++) {
                const k = snapKeys[i];
                if (k === id) {
                    newExts[k] = entryToRestore;
                } else if (root.config.extensions.hasOwnProperty(k)) {
                    newExts[k] = root.config.extensions[k];
                }
            }
            const currentKeys = Object.keys(root.config.extensions);
            for (let i = 0; i < currentKeys.length; i++) {
                const k = currentKeys[i];
                if (!newExts.hasOwnProperty(k)) {
                    newExts[k] = root.config.extensions[k];
                }
            }
            if (!newExts.hasOwnProperty(id)) {
                newExts[id] = entryToRestore;
            }
            root.config.extensions = newExts;
        } else {
            root.config.extensions[id] = entryToRestore;
        }

        if (snap && Array.isArray(snap.extensionOrder) && snap.extensionOrder.indexOf(id) !== -1) {
            const targetIdx = snap.extensionOrder.indexOf(id);
            if (root.config.extensionOrder.indexOf(id) === -1) {
                root.config.extensionOrder.splice(Math.min(targetIdx, root.config.extensionOrder.length), 0, id);
            }
        }
    }

    function syncFromConfig() {
        installedExtensionsList.syncFromConfig();
        orphansRepeater.model = getOrphanedExtensionIds();
    }

    onExtensionsListChanged: syncFromConfig()
    onConfigChanged: syncFromConfig()
    Component.onCompleted: syncFromConfig()

    // 1. INSTALLED EXTENSIONS LIST
    ExtensionsList {
        id: installedExtensionsList
        Layout.fillWidth: true
        config: root.config
        extensionsList: root.extensionsList
        appWindow: root.appWindow
        onSettingModified: root.settingModified()
        onRequestRemoveExtension: (extId, keepSettings) => root.requestRemoveExtension(extId, keepSettings)
    }

    // 2. ORPHANED EXTENSIONS SECTION (Removed but with retained settings)
    ColumnLayout {
        Layout.fillWidth: true
        visible: orphansRepeater.count > 0
        spacing: Kirigami.Units.mediumSpacing

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.mediumSpacing
            spacing: 2

            Kirigami.Heading {
                level: 3
                text: ki18n.i18nc("@title:group", "Removed or Missing")
            }

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: ki18n.i18n("Unavailable. Reinstalling the plugin will restore its settings.")
                font.pixelSize: 11
                color: Kirigami.Theme.disabledTextColor
            }
        }

        Repeater {
            id: orphansRepeater
            model: []
            delegate: Kirigami.AbstractCard {
                id: orphanCard
                required property int index
                required property string modelData
                property bool pendingDelete: !root.config || !root.config.extensions || !root.config.extensions[orphanCard.modelData]
                property var backupEntry: null

                Layout.fillWidth: true
                showClickFeedback: false
                hoverEnabled: false
                opacity: pendingDelete ? 0.45 : 1.0

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                contentItem: RowLayout {
                    spacing: Kirigami.Units.mediumSpacing

                    Kirigami.Icon {
                        source: "dialog-warning"
                        implicitWidth: 24
                        implicitHeight: 24
                        color: Kirigami.Theme.negativeTextColor
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: orphanCard.modelData
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    QQC2.Button {
                        text: orphanCard.pendingDelete
                              ? ki18n.i18nc("@action:button", "Cancel")
                              : ki18n.i18nc("@action:button", "Delete data")
                        icon.name: orphanCard.pendingDelete ? "dialog-cancel" : "edit-delete"
                        flat: true
                        onClicked: {
                            if (!orphanCard.pendingDelete) {
                                if (root.config && root.config.extensions && root.config.extensions[orphanCard.modelData]) {
                                    orphanCard.backupEntry = JSON.parse(JSON.stringify(root.config.extensions[orphanCard.modelData]));
                                }
                                delete root.config.extensions[orphanCard.modelData];
                                if (Array.isArray(root.config.extensionOrder)) {
                                    root.config.extensionOrder = root.config.extensionOrder.filter(id => id !== orphanCard.modelData);
                                }
                                orphanCard.pendingDelete = true;
                            } else {
                                root.restoreOrphanData(orphanCard.modelData, orphanCard.backupEntry);
                                orphanCard.pendingDelete = false;
                            }
                            root.settingModified();
                        }
                    }
                }
            }
        }
    }

    // 3. USER ACTIONS FOOTER
    Kirigami.Separator {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.mediumSpacing
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.mediumSpacing

        QQC2.Button {
            icon.name: "folder-open"
            text: ki18n.i18nc("@action:button", "Open extensions folder…")
            onClicked: {
                if (root.appWindow && root.appWindow.runCommand) {
                    root.appWindow.runCommand("mkdir -p ~/.local/share/aod4kde/extensions && xdg-open ~/.local/share/aod4kde/extensions");
                }
            }
        }

        QQC2.Button {
            icon.name: "view-refresh"
            text: ki18n.i18nc("@action:button", "Reload")
            onClicked: root.requestReloadExtensions()
        }

        Item {
            Layout.fillWidth: true
        }
    }
}
