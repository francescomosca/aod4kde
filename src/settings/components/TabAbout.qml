import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.ki18n

ColumnLayout {
    id: root
    spacing: Kirigami.Units.largeSpacing

    KI18nContext {
        id: ki18n
        translationDomain: "aod4kde"
    }

    GridLayout {
        columns: 2
        Layout.fillWidth: true
        columnSpacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            Layout.rowSpan: 2
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            Layout.preferredWidth: height
            source: "preferences-desktop-display"
        }

        Kirigami.Heading {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom
            text: "AOD4KDE"
            textFormat: Text.PlainText
        }

        Kirigami.Heading {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            level: 3
            type: Kirigami.Heading.Type.Secondary
            wrapMode: Text.WordWrap
            text: ki18n.i18n("Customizable Always-On-Display screen for KDE Plasma 6 with hardware stats, notifications, and burn-in protection.")
            textFormat: Text.PlainText
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        level: 3
        text: ki18n.i18nc("@title:group", "Repository")
        textFormat: Text.PlainText
    }

    RowLayout {
        Layout.leftMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            source: "globe"
        }

        Kirigami.UrlButton {
            url: "https://github.com/francescomosca/aod4kde"
            text: "https://github.com/francescomosca/aod4kde"
        }
    }

    Kirigami.Heading {
        level: 3
        text: ki18n.i18nc("@title:group", "Copyright")
        textFormat: Text.PlainText
    }

    ColumnLayout {
        Layout.leftMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            text: ki18n.i18n("License: GPL-2.0+")
            textFormat: Text.PlainText
        }
    }

    Kirigami.Heading {
        level: 3
        text: ki18n.i18nc("@title:group", "Authors")
        textFormat: Text.PlainText
    }

    RowLayout {
        Layout.leftMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing * 2

        Kirigami.Icon {
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: implicitWidth
            source: "user"
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: "Francesco Mosca"
            textFormat: Text.PlainText
        }
    }
}
