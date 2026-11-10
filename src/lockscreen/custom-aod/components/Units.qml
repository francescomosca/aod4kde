pragma Singleton
import QtQuick

QtObject {
    id: root
    property real scale: 1.0

    function dp(val) {
        return Math.round(val * root.scale);
    }
}

