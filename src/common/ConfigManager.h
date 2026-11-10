#pragma once

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QStandardPaths>
#include <QSet>
#include <QString>
#include <filesystem>
#include <system_error>

namespace AodCommon {

inline QString configPath() {
    return QDir::homePath() + "/.config/aod4kde.json";
}

inline bool hasSystemBattery() {
    QDir dir(QStringLiteral("/sys/class/power_supply"));
    if (!dir.exists()) {
        return false;
    }
    const QFileInfoList entries = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo &entry : entries) {
        QFile typeFile(entry.absoluteFilePath() + QStringLiteral("/type"));
        if (!typeFile.open(QIODevice::ReadOnly)) {
            continue;
        }
        const QByteArray type = typeFile.readAll().trimmed();
        if (type != "Battery" && type != "UPS") {
            continue;
        }

        // Ignore peripheral batteries (e.g. wireless mice, keyboards, gamepads)
        QFile scopeFile(entry.absoluteFilePath() + QStringLiteral("/scope"));
        if (scopeFile.open(QIODevice::ReadOnly)) {
            const QByteArray scope = scopeFile.readAll().trimmed();
            if (scope.compare("Device", Qt::CaseInsensitive) == 0) {
                continue;
            }
        }

        QFile presentFile(entry.absoluteFilePath() + QStringLiteral("/present"));
        if (presentFile.open(QIODevice::ReadOnly)) {
            if (presentFile.readAll().trimmed() == "0") {
                continue;
            }
        }

        return true;
    }
    return false;
}

inline QJsonObject loadConfig(const QString &path = configPath()) {
    QFile file(path);
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        if (doc.isObject()) {
            return doc.object();
        }
    }
    return QJsonObject();
}

inline bool saveConfigDocument(const QJsonDocument &doc, const QString &path = configPath(), QString *errorOut = nullptr) {
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        if (errorOut) *errorOut = QStringLiteral("Cannot open ") + path;
        return false;
    }
    file.write(doc.toJson(QJsonDocument::Indented));
    if (!file.commit()) {
        if (errorOut) *errorOut = QStringLiteral("Commit failed on ") + path;
        return false;
    }
    return true;
}

inline bool saveConfig(const QJsonObject &obj, const QString &path = configPath(), QString *errorOut = nullptr) {
    return saveConfigDocument(QJsonDocument(obj), path, errorOut);
}

inline void ensureConfigExists(const QString &path = configPath()) {
    if (QFile::exists(path)) {
        return;
    }

    const QStringList candidates = {
        QDir::homePath() + "/.local/share/aod4kde/default-config.json",
        "/usr/local/share/aod4kde/default-config.json",
        "/usr/share/aod4kde/default-config.json",
        QCoreApplication::applicationDirPath() + "/../settings/default-config.json"
    };

    for (const QString &defaultCfg : candidates) {
        if (QFile::exists(defaultCfg)) {
            std::error_code ec;
            std::filesystem::create_directories(QFileInfo(path).absolutePath().toStdString(), ec);
            QJsonObject obj = loadConfig(defaultCfg);
            if (!obj.isEmpty()) {
                if (!hasSystemBattery()) {
                    obj["showBattery"] = false;
                }
                saveConfig(obj, path);
            }
            break;
        }
    }
}

inline bool saveConfigBytes(const QByteArray &jsonBytes, const QString &path = configPath(), QString *errorOut = nullptr) {
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(jsonBytes, &err);
    if (err.error != QJsonParseError::NoError) {
        if (errorOut) *errorOut = QStringLiteral("JSON error: ") + err.errorString();
        return false;
    }
    return saveConfigDocument(doc, path, errorOut);
}

inline bool isAodEnabled(const QString &path = configPath()) {
    return loadConfig(path).value("enabled").toBool(true);
}

inline bool setAodEnabled(bool enabled, const QString &path = configPath()) {
    QJsonObject obj = loadConfig(path);
    obj["enabled"] = enabled;
    return saveConfig(obj, path);
}

inline QString lockscreenQmlPath() {
    return QStringLiteral("/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockScreenUi.qml");
}

inline QString patchFailedMarkerPath() {
    return QStringLiteral("/usr/share/aod4kde/lockscreen/.patch_failed");
}

inline bool isLockscreenIncompatible() {
    if (QFile::exists(patchFailedMarkerPath())) {
        return true;
    }
    QFile uiFile(lockscreenQmlPath());
    if (uiFile.exists() && uiFile.open(QIODevice::ReadOnly)) {
        const QByteArray content = uiFile.readAll();
        if (!content.contains("id: aodManager")) {
            return true;
        }
    }
    return false;
}

inline QString daemonFailuresPath() {
    QString runDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (runDir.isEmpty() || !QDir(runDir).exists()) {
        runDir = QDir::tempPath();
    }
    return runDir + QStringLiteral("/aod4kde-crashed-daemons.json");
}

inline QSet<QString> loadFailedDaemons() {
    QFile f(daemonFailuresPath());
    if (f.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        if (doc.isArray()) {
            QSet<QString> set;
            for (const auto &v : doc.array()) {
                QString id = v.toString().trimmed();
                if (!id.isEmpty()) set.insert(id);
            }
            return set;
        }
    }
    return {};
}

inline void saveFailedDaemons(const QSet<QString> &failedSet) {
    const QString path = daemonFailuresPath();
    if (failedSet.isEmpty()) {
        QFile::remove(path);
        return;
    }
    QJsonArray arr;
    for (const QString &id : failedSet) {
        arr.append(id);
    }
    QSaveFile sf(path);
    if (sf.open(QIODevice::WriteOnly)) {
        sf.write(QJsonDocument(arr).toJson(QJsonDocument::Compact));
        sf.commit();
    }
}

inline void clearDaemonFailure(const QString &id) {
    QSet<QString> current = loadFailedDaemons();
    if (current.remove(id)) {
        saveFailedDaemons(current);
    }
}

} // namespace AodCommon

