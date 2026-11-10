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

    property string pendingRemoveId: ""
    property string pendingRemoveName: ""
    property bool pendingRemoveHasSettings: false

    signal settingModified()
    signal requestRemoveExtension(string extensionId, bool keepSettings)

    KI18nContext {
        id: ki18n
        translationDomain: "aod4kde"
    }

    function ensureConfigStructure() {
        if (!root.config) return;
        if (!root.config.extensions) {
            root.config.extensions = {};
        }
        if (!Array.isArray(root.config.extensionOrder)) {
            root.config.extensionOrder = [];
        }

        // Initialize extensions with defaultConfig if not present
        if (!root.extensionsList || !Array.isArray(root.extensionsList)) return;
        for (let i = 0; i < root.extensionsList.length; i++) {
            const ext = root.extensionsList[i];
            const id = ext.id;
            if (!root.config.extensions[id]) {
                const baseConfig = JSON.parse(JSON.stringify(ext.defaultConfig || {}));
                root.config.extensions[id] = {
                    "enabled": ext.isBuiltIn === true,
                    "config": baseConfig
                };
            } else if (!root.config.extensions[id].config) {
                root.config.extensions[id].config = JSON.parse(JSON.stringify(ext.defaultConfig || {}));
            }
            if (root.config.extensionOrder.indexOf(id) === -1) {
                root.config.extensionOrder.push(id);
            }
        }
    }

    function isExtensionEnabled(id) {
        if (!root.config || !root.config.extensions || !root.config.extensions[id]) return false;
        return root.config.extensions[id].enabled === true;
    }

    function setExtensionEnabled(id, val) {
        ensureConfigStructure();
        root.config.extensions[id].enabled = val;
        root.settingModified();
    }

    function getExtensionConfig(id) {
        ensureConfigStructure();
        if (!root.config.extensions[id]) {
            root.config.extensions[id] = { "enabled": false, "config": {} };
        }
        if (!root.config.extensions[id].config) {
            root.config.extensions[id].config = {};
        }
        return root.config.extensions[id].config;
    }

    function saveOrderFromModel() {
        ensureConfigStructure();
        let newOrder = [];
        for (let i = 0; i < extensionsModel.count; i++) {
            newOrder.push(extensionsModel.get(i).id);
        }
        root.config.extensionOrder = newOrder;
        root.settingModified();
    }

    function getOrderedExtensions() {
        ensureConfigStructure();
        const order = root.config.extensionOrder || [];
        const list = (root.extensionsList || []).slice();

        // Sort according to user-configured order if present
        return list.sort((a, b) => {
            const idxA = order.indexOf(a.id);
            const idxB = order.indexOf(b.id);
            if (idxA !== -1 && idxB !== -1) return idxA - idxB;
            if (idxA !== -1) return -1;
            if (idxB !== -1) return 1;
            return a.name.localeAwareCompare(b.name);
        });
    }

    function syncFromConfig() {
        ensureConfigStructure();
        const ordered = getOrderedExtensions();

        let needsRebuild = (extensionsModel.count !== ordered.length);
        if (!needsRebuild) {
            for (let i = 0; i < ordered.length; i++) {
                if (extensionsModel.get(i).id !== ordered[i].id || extensionsModel.get(i).daemonFailed !== (ordered[i].daemonFailed === true)) {
                    needsRebuild = true;
                    break;
                }
            }
        }

        if (needsRebuild) {
            extensionsModel.clear();
            for (let i = 0; i < ordered.length; i++) {
                const item = ordered[i];
                extensionsModel.append({
                    "id": item.id || "",
                    "name": item.name || "",
                    "description": item.description || "",
                    "icon": item.icon || "preferences-plugin",
                    "version": item.version || "1.0.0",
                    "author": item.author || (item.isBuiltIn ? ki18n.i18n("System") : ki18n.i18n("Community")),
                    "isBuiltIn": item.isBuiltIn === true,
                    "settingsQml": item.settingsQml || "",
                    "daemonFailed": item.daemonFailed === true
                });
            }
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        visible: extensionsModel.count === 0
        text: ki18n.i18n("No extensions installed.")
        color: Kirigami.Theme.disabledTextColor
        font.italic: true
    }

    ListView {
        id: extensionsListView
        Layout.fillWidth: true
        implicitHeight: contentHeight
        interactive: false
        spacing: Kirigami.Units.mediumSpacing
        clip: false

        moveDisplaced: Transition {
            YAnimator {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }

        model: ListModel {
            id: extensionsModel
        }

        delegate: Item {
            id: delegateWrapper
            width: extensionsListView.width
            implicitHeight: extCard.implicitHeight

            ExtensionCard {
                id: extCard
                width: parent.width
                listView: extensionsListView
                dragListItem: extCard
                showDragHandle: true

                title: model.name || ""
                description: model.description || ""
                iconName: model.icon || "preferences-plugin"
                version: model.version || "1.0.0"
                author: model.author || (model.isBuiltIn ? ki18n.i18n("System") : ki18n.i18n("Community"))
                isBuiltIn: model.isBuiltIn === true
                extensionEnabled: root.isExtensionEnabled(model.id)
                daemonFailed: model.daemonFailed === true
                hasSettings: (model.settingsQml && model.settingsQml.length > 0)
                settingsQmlUrl: model.settingsQml || ""
                extensionConfig: root.getExtensionConfig(model.id)
                appWindow: root.appWindow

                onRetryDaemonRequested: {
                    if (root.appWindow && root.appWindow.retryDaemon) {
                        root.appWindow.retryDaemon(model.id);
                    }
                }

                onExtensionToggled: (newState) => {
                    root.setExtensionEnabled(model.id, newState);
                    extensionEnabled = newState;
                }
                onSettingModified: root.settingModified()
                onMoveRequested: (oldIndex, newIndex) => {
                    extensionsModel.move(oldIndex, newIndex, 1);
                }
                onDropped: (oldIndex, newIndex) => {
                    root.saveOrderFromModel();
                }
                onRemoveRequested: {
                    extCard.expanded = false;
                    root.pendingRemoveId = model.id;
                    root.pendingRemoveName = model.name || model.id;
                    root.pendingRemoveHasSettings = (model.settingsQml && model.settingsQml.length > 0);
                    keepSettingsCheckBox.checked = false;
                    removeConfirmDialog.open();
                }
            }
        }
    }

    Kirigami.Dialog {
        id: removeConfirmDialog
        parent: QQC2.Overlay.overlay
        title: ki18n.i18nc("@title:window", "Remove Extension")
        preferredWidth: Kirigami.Units.gridUnit * 22
        padding: Kirigami.Units.largeSpacing
        standardButtons: Kirigami.Dialog.NoButton

        customFooterActions: [
            Kirigami.Action {
                text: ki18n.i18nc("@action:button", "Remove")
                icon.name: "edit-delete"
                onTriggered: {
                    const extId = root.pendingRemoveId;
                    const keepCfg = root.pendingRemoveHasSettings && keepSettingsCheckBox.checked;
                    removeConfirmDialog.close();
                    if (extId.length > 0) {
                        root.requestRemoveExtension(extId, keepCfg);
                    }
                }
            },
            Kirigami.Action {
                text: ki18n.i18nc("@action:button", "Cancel")
                icon.name: "dialog-cancel"
                onTriggered: {
                    removeConfirmDialog.close();
                }
            }
        ]

        ColumnLayout {
            spacing: Kirigami.Units.mediumSpacing

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: ki18n.i18n("Are you sure you want to remove \"%1\"? Its files will be permanently deleted.", root.pendingRemoveName)
            }

            QQC2.CheckBox {
                id: keepSettingsCheckBox
                Layout.fillWidth: true
                visible: root.pendingRemoveHasSettings
                text: ki18n.i18nc("@option:check", "Keep saved extension settings")
                checked: false
            }
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: ki18n.i18n("Widgets are shown in AOD in the order above. Drag the handle to reorder them.")
        font.pixelSize: 11
        color: Kirigami.Theme.disabledTextColor
    }
}

