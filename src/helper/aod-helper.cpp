#include <QCoreApplication>
#include <QByteArray>
#include <QJsonDocument>
#include <QJsonArray>
#include <QString>
#include <QSettings>
#include <QDir>
#include <iostream>
#include <klocalizedstring.h>
#include "../common/ConfigManager.h"
#include "../common/ExtensionScanner.h"

static int doSave(int argc, char *argv[]) {
    if (argc < 3) return 1;
    QByteArray jsonBytes;
    if (QString(argv[2]) == "--hex" && argc > 3) {
        jsonBytes = QByteArray::fromHex(argv[3]);
    } else {
        jsonBytes = QByteArray(argv[2]);
    }

    QString errMsg;
    if (!AodCommon::saveConfigBytes(jsonBytes, AodCommon::configPath(), &errMsg)) {
        std::cerr << errMsg.toStdString() << std::endl;
        return 1;
    }
    std::cout << "OK" << std::endl;
    return 0;
}

static int doExtensions() {
    QJsonArray result = AodCommon::getSortedExtensions();
    QJsonDocument outDoc(result);
    std::cout << outDoc.toJson(QJsonDocument::Compact).toStdString() << std::endl;
    return 0;
}

static int doRemoveExtension(int argc, char *argv[]) {
    if (argc < 3) return 1;
    QString extId = QString::fromUtf8(argv[2]).trimmed();
    if (extId.isEmpty()) return 1;
    bool ok = AodCommon::removeUserExtension(extId);
    std::cout << (ok ? "OK" : "NOT_FOUND") << std::endl;
    return ok ? 0 : 1;
}

static int doResetDaemonFailure(int argc, char *argv[]) {
    if (argc < 3) return 1;
    QString extId = QString::fromUtf8(argv[2]).trimmed();
    if (extId.isEmpty()) return 1;
    AodCommon::clearDaemonFailure(extId);
    std::cout << "OK" << std::endl;
    return 0;
}

static int doCheckDpms() {
    // 1. Read screen locker timeout from kscreenlockerrc
    QString kscreenlockerrcPath = QDir::homePath() + QStringLiteral("/.config/kscreenlockerrc");
    QSettings lockerSettings(kscreenlockerrcPath, QSettings::IniFormat);

    int lockTimeoutMin = lockerSettings.value(QStringLiteral("Daemon/Timeout"), 5).toInt();
    if (lockTimeoutMin <= 0) {
        lockTimeoutMin = 5;
    }
    int lockTimeoutSec = lockTimeoutMin * 60;

    // 2. Read powerdevilrc
    QString powerdevilrcPath = QDir::homePath() + QStringLiteral("/.config/powerdevilrc");
    QSettings powerSettings(powerdevilrcPath, QSettings::IniFormat);

    bool hasBattery = AodCommon::hasSystemBattery();
    bool dpmsProblematic = false;

    // Check AC profile
    QVariant acWhenIdle = powerSettings.value(QStringLiteral("AC/TurnOffDisplayWhenIdle"));
    int acSec = powerSettings.value(QStringLiteral("AC/TurnOffDisplayIdleTimeoutSec"), -999).toInt();

    // Default in KDE 6: TurnOffDisplayWhenIdle=true, TurnOffDisplayIdleTimeoutSec=600 (10 min)
    bool acEnabled = true;
    if (acWhenIdle.isValid()) {
        QString s = acWhenIdle.toString().trimmed();
        if (s.compare(QLatin1String("false"), Qt::CaseInsensitive) == 0 || s == QLatin1String("0")) {
            acEnabled = false;
        }
    }
    if (acSec == -1 || acSec == 0) {
        acEnabled = false;
    } else if (acSec == -999) {
        acSec = 600;
    }

    if (acEnabled && acSec > 0 && acSec <= lockTimeoutSec) {
        dpmsProblematic = true;
    }

    // Check Battery profile only if system has battery
    if (hasBattery && !dpmsProblematic) {
        QVariant batWhenIdle = powerSettings.value(QStringLiteral("Battery/TurnOffDisplayWhenIdle"));
        int batSec = powerSettings.value(QStringLiteral("Battery/TurnOffDisplayIdleTimeoutSec"), -999).toInt();

        // Default in KDE 6: TurnOffDisplayWhenIdle=true, TurnOffDisplayIdleTimeoutSec=300 (5 min)
        bool batEnabled = true;
        if (batWhenIdle.isValid()) {
            QString s = batWhenIdle.toString().trimmed();
            if (s.compare(QLatin1String("false"), Qt::CaseInsensitive) == 0 || s == QLatin1String("0")) {
                batEnabled = false;
            }
        }
        if (batSec == -1 || batSec == 0) {
            batEnabled = false;
        } else if (batSec == -999) {
            batSec = 300;
        }

        if (batEnabled && batSec > 0 && batSec <= lockTimeoutSec) {
            dpmsProblematic = true;
        }
    }

    std::cout << (dpmsProblematic ? "DPMS_ACTIVE:true" : "DPMS_ACTIVE:false") << std::endl;
    return 0;
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    KLocalizedString::setApplicationDomain("aod4kde");

    if (argc > 1) {
        QString cmd = argv[1];
        if (cmd == "save") {
            return doSave(argc, argv);
        } else if (cmd == "extensions") {
            return doExtensions();
        } else if (cmd == "remove-extension") {
            return doRemoveExtension(argc, argv);
        } else if (cmd == "reset-daemon-failure") {
            return doResetDaemonFailure(argc, argv);
        } else if (cmd == "check-dpms") {
            return doCheckDpms();
        } else if (cmd == "has-battery") {
            std::cout << (AodCommon::hasSystemBattery() ? "true" : "false") << std::endl;
            return 0;
        }
    }

    return 0;
}
