.pragma library

const listeners = [];
const screenUiStates = {};
const screenNames = {};
const screenPrimary = {};
let screenCounter = 0;
let initialGrace = true;
let anyUiVisible = true;
let activeScreenId = null;
let primaryScreenId = null;
let aodTargetId = null;
let syncedConfig = null;

let onlyOnCustomScreen = false;
let targetScreen = "";

function notifyListeners() {
    for (let i = listeners.length - 1; i >= 0; i--) {
        try {
            listeners[i](anyUiVisible, aodTargetId, syncedConfig);
        } catch (e) {
            listeners.splice(i, 1);
        }
    }
}

function resolveAodScreen() {
    let chosenId = null;

    // 1. If configured to show only on a specific screen and it is connected
    if (onlyOnCustomScreen && targetScreen) {
        const found = Object.entries(screenNames).find(([, name]) => name === targetScreen);
        if (found) {
            chosenId = found[0];
        }
    }

    // 2. Fallback if not custom or targetScreen was not found (e.g. disconnected)
    if (chosenId === null) {
        if (primaryScreenId && screenUiStates.hasOwnProperty(primaryScreenId)) {
            chosenId = primaryScreenId;
        } else if (activeScreenId && screenUiStates.hasOwnProperty(activeScreenId)) {
            chosenId = activeScreenId;
        } else {
            const firstScreen = Object.keys(screenUiStates)[0];
            chosenId = firstScreen ?? null;
        }
    }

    const changed = (chosenId !== aodTargetId);
    aodTargetId = chosenId;
    console.warn(`AOD_SYNC: resolveAodScreen -> chosen=${aodTargetId} (onlyCustom=${onlyOnCustomScreen}, target=${targetScreen}, registered=${JSON.stringify(screenNames)}, primary=${primaryScreenId}, active=${activeScreenId})`);
    return changed;
}

function updateAnyUiVisible() {
    const any = initialGrace || Object.values(screenUiStates).some(Boolean);
    const uiChanged = (any !== anyUiVisible);
    anyUiVisible = any;
    const targetChanged = resolveAodScreen();
    if (uiChanged || targetChanged) {
        notifyListeners();
    }
}

function endInitialGrace() {
    initialGrace = false;
    updateAnyUiVisible();
}

function registerScreen(initialUiVisible = false, isActive = false, screenName = "", isPrimary = false) {
    const id = `screen_${++screenCounter}`;
    screenUiStates[id] = Boolean(initialUiVisible);
    if (screenName) {
        screenNames[id] = screenName;
    }
    screenPrimary[id] = Boolean(isPrimary);
    if (isPrimary || primaryScreenId === null) {
        primaryScreenId = id;
    }
    if (isActive || activeScreenId === null) {
        activeScreenId = id;
    }
    console.warn(`AOD_SYNC: registerScreen id=${id} screenName=${screenName} primary=${isPrimary} active=${isActive}`);
    updateAnyUiVisible();
    return id;
}

function unregisterScreen(screenId) {
    if (!screenId) return;
    delete screenUiStates[screenId];
    delete screenNames[screenId];
    delete screenPrimary[screenId];
    if (activeScreenId === screenId) {
        activeScreenId = null;
    }
    if (primaryScreenId === screenId) {
        primaryScreenId = Object.keys(screenPrimary).find(id => screenPrimary[id]) ?? null;
    }
    console.warn(`AOD_SYNC: unregisterScreen id=${screenId}`);
    updateAnyUiVisible();
}

function setScreenName(screenId, sName) {
    if (!screenId || !sName) return;
    if (screenNames[screenId] !== sName) {
        screenNames[screenId] = sName;
        console.warn(`AOD_SYNC: setScreenName id=${screenId} -> ${sName}`);
        if (resolveAodScreen()) {
            notifyListeners();
        }
    }
}

function setScreenPrimary(screenId, isPrimary) {
    if (!screenId) return;
    const prim = Boolean(isPrimary);
    if (screenPrimary[screenId] !== prim) {
        screenPrimary[screenId] = prim;
        if (prim) {
            primaryScreenId = screenId;
        } else if (primaryScreenId === screenId) {
            primaryScreenId = Object.keys(screenPrimary).find(id => screenPrimary[id]) ?? null;
        }
        console.warn(`AOD_SYNC: setScreenPrimary id=${screenId} -> ${prim}`);
        if (resolveAodScreen()) {
            notifyListeners();
        }
    }
}

function setScreenConfig(cfg) {
    if (!cfg) return;
    try {
        if (syncedConfig && JSON.stringify(syncedConfig) === JSON.stringify(cfg)) {
            return;
        }
    } catch(e) {}
    syncedConfig = cfg;
    const prevOnly = onlyOnCustomScreen;
    const prevTarget = targetScreen;
    onlyOnCustomScreen = Boolean(cfg.onlyOnCustomScreen);
    targetScreen = cfg.targetScreen ?? "";
    console.warn(`AOD_SYNC: setScreenConfig onlyOnCustom=${onlyOnCustomScreen} targetScreen=${targetScreen}`);
    resolveAodScreen();
    notifyListeners();
}

function getScreenConfig() {
    return syncedConfig;
}

function setScreenUiVisible(screenId, isVisible) {
    if (!screenId) return;
    screenUiStates[screenId] = Boolean(isVisible);
    updateAnyUiVisible();
}

function setActiveScreen(screenId, isActive) {
    if (!screenId) return;
    if (isActive && activeScreenId !== screenId) {
        activeScreenId = screenId;
        console.warn(`AOD_SYNC: setActiveScreen id=${screenId}`);
        if (resolveAodScreen()) {
            notifyListeners();
        }
    }
}

function subscribe(callback) {
    listeners.push(callback);
    try {
        callback(anyUiVisible, aodTargetId, syncedConfig);
    } catch (e) {
        console.error("AodSync subscribe error:", e);
    }
    return function unsubscribe() {
        const idx = listeners.indexOf(callback);
        if (idx !== -1) {
            listeners.splice(idx, 1);
        }
    };
}
