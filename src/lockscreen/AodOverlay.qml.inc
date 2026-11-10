        // --- START AOD4KDE PATCH ---
        Item {
            id: aodManager
            anchors.fill: parent
            z: 98

            property string screenId: ""
            property bool anyUiVisible: true
            property bool isAodScreen: false
            property string detectedScreenName: ""
            property var unsubscribeFunc: null

            readonly property bool hasActiveMonitor: (typeof activeScreenMonitor !== "undefined" && activeScreenMonitor !== null && activeScreenMonitor.active !== undefined)
            readonly property bool screenActive: hasActiveMonitor ? activeScreenMonitor.active : false

            function queryScreenName() {
                var name = "";
                if (typeof Screen !== "undefined" && Screen.name && Screen.name.length > 0) {
                    name = Screen.name;
                } else if (lockScreenRoot.Window && lockScreenRoot.Window.window && lockScreenRoot.Window.window.screen && lockScreenRoot.Window.window.screen.name) {
                    name = lockScreenRoot.Window.window.screen.name;
                }
                return name;
            }

            function queryIsPrimary() {
                try {
                    var winScreen = (lockScreenRoot.Window && lockScreenRoot.Window.window) ? lockScreenRoot.Window.window.screen : null;
                    if (typeof Qt !== "undefined" && Qt.application && Qt.application.screens && Qt.application.screens.length > 0) {
                        var primary = Qt.application.screens[0];
                        if (winScreen && winScreen === primary) {
                            return true;
                        }
                        var sName = queryScreenName();
                        if (primary && primary.name && sName && primary.name === sName) {
                            return true;
                        }
                    }
                } catch(e) {}
                return false;
            }

            function updateScreenName() {
                var name = queryScreenName();
                var isPrim = queryIsPrimary();
                if (name && name.length > 0 && name !== detectedScreenName) {
                    detectedScreenName = name;
                    if (screenId !== "") {
                        AodSync.setScreenName(screenId, name);
                    }
                }
                if (screenId !== "") {
                    AodSync.setScreenPrimary(screenId, isPrim);
                }
            }

            Component.onCompleted: {
                detectedScreenName = queryScreenName();
                var isPrim = queryIsPrimary();
                screenId = AodSync.registerScreen(lockScreenRoot.uiVisible, screenActive, detectedScreenName, isPrim);
                unsubscribeFunc = AodSync.subscribe(function(anyUi, activeId, sharedConfig) {
                    aodManager.anyUiVisible = anyUi;
                    aodManager.isAodScreen = (activeId === aodManager.screenId);
                    if (sharedConfig && !aodManager.isAodScreen) {
                        aodClockStats.aodConfig = sharedConfig;
                    }
                });
                var existingCfg = AodSync.getScreenConfig();
                if (existingCfg && !aodManager.isAodScreen) {
                    aodClockStats.aodConfig = existingCfg;
                } else {
                    AodSync.setScreenConfig(aodClockStats.aodConfig);
                }
                updateScreenName();
            }

            Component.onDestruction: {
                if (typeof unsubscribeFunc === "function") {
                    unsubscribeFunc();
                }
                if (screenId !== "") {
                    AodSync.unregisterScreen(screenId);
                }
            }

            // Periodic retry to ensure screen name is captured once window is exposed by LayerShell
            Timer {
                interval: 50
                running: aodManager.detectedScreenName === ""
                repeat: true
                onTriggered: {
                    aodManager.updateScreenName();
                    if (aodManager.detectedScreenName !== "") {
                        running = false;
                    }
                }
            }

            Timer {
                interval: 500
                running: true
                repeat: false
                onTriggered: {
                    aodManager.updateScreenName();
                    AodSync.endInitialGrace();
                }
            }

            Connections {
                target: lockScreenRoot
                function onUiVisibleChanged() {
                    if (aodManager.screenId !== "") {
                        AodSync.setScreenUiVisible(aodManager.screenId, lockScreenRoot.uiVisible);
                    }
                }
            }

            Connections {
                target: aodManager.hasActiveMonitor ? activeScreenMonitor : null
                function onActiveChanged() {
                    if (aodManager.screenId !== "" && activeScreenMonitor.active) {
                        AodSync.setActiveScreen(aodManager.screenId, true);
                    }
                }
            }

            Connections {
                target: aodManager
                function onAnyUiVisibleChanged() {
                    if (!aodManager.anyUiVisible && aodManager.isAodScreen) {
                        aodClockStats.reloadData();
                    }
                }
                function onIsAodScreenChanged() {
                    if (aodManager.isAodScreen && !aodManager.anyUiVisible) {
                        aodClockStats.reloadData();
                    }
                }
            }

            Connections {
                target: aodClockStats
                function onAodConfigChanged() {
                    AodSync.setScreenConfig(aodClockStats.aodConfig);
                }
            }

            Rectangle {
                id: aodBlackBackground
                anchors.fill: parent
                color: "#000000"
                z: 1
                readonly property bool showBg: !!aodClockStats.aodConfig.showBackground
                readonly property real targetOpacity: {
                    if (aodManager.anyUiVisible || aodClockStats.aodConfig.enabled === false) {
                        return 0.0;
                    }
                    if (showBg) {
                        var val = Number(aodClockStats.aodConfig.backgroundOpacity !== undefined ? aodClockStats.aodConfig.backgroundOpacity : 20);
                        if (isNaN(val)) val = 20;
                        val = Math.max(0, Math.min(100, val));
                        return (100.0 - val) / 100.0;
                    }
                    return 1.0;
                }
                visible: opacity > 0
                opacity: targetOpacity
                Behavior on opacity {
                    NumberAnimation {
                        duration: aodManager.anyUiVisible ? Kirigami.Units.shortDuration : Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            AodClockStats {
                id: aodClockStats
                anchors.fill: parent
                z: 2
                visible: opacity > 0 && aodManager.isAodScreen
                opacity: (!aodManager.anyUiVisible && aodClockStats.aodConfig.enabled !== false && aodManager.isAodScreen) ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: aodManager.anyUiVisible ? Kirigami.Units.shortDuration : Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
        // --- END AOD4KDE PATCH ---
