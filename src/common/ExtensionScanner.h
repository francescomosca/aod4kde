#pragma once

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <QList>
#include <QString>
#include <QLocale>
#include <QSet>
#include <algorithm>
#include <klocalizedstring.h>
#include "ConfigManager.h"

namespace AodCommon {

struct ExtensionDir {
    QString path;
    bool isBuiltIn;
};

inline QList<ExtensionDir> getExtensionSearchDirs() {
    QList<ExtensionDir> dirs;

    // 1. Built-in system paths
    dirs.append({"/usr/share/aod4kde/extensions", true});
    dirs.append({"/usr/local/share/aod4kde/extensions", true});

    // Local development path (if running from source repository)
    QString devExtPath = QCoreApplication::applicationDirPath() + "/../extensions";
    if (QDir(devExtPath).exists()) {
        dirs.prepend({QDir(devExtPath).canonicalPath(), true});
    }

    // 2. User path (Community / Third-party)
    QString userExtPath = QDir::homePath() + "/.local/share/aod4kde/extensions";
    dirs.append({userExtPath, false});

    return dirs;
}

inline QMap<QString, QJsonObject> scanExtensions() {
    QMap<QString, QJsonObject> extensionsMap;
    const auto searchDirs = getExtensionSearchDirs();
    const QSet<QString> failedDaemons = loadFailedDaemons();

    for (const auto &sd : searchDirs) {
        QDir rootDir(sd.path);
        if (!rootDir.exists()) continue;

        const QFileInfoList subdirs = rootDir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const auto &sub : subdirs) {
            QString metaPath = sub.absoluteFilePath() + "/metadata.json";
            if (!QFile::exists(metaPath)) continue;

            QFile metaFile(metaPath);
            if (!metaFile.open(QIODevice::ReadOnly)) continue;

            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(metaFile.readAll(), &err);
            if (err.error != QJsonParseError::NoError || !doc.isObject()) continue;

            QJsonObject meta = doc.object();
            QString id = meta.value("id").toString().trimmed();
            QString name = meta.value("name").toString().trimmed();
            QString lockQml = meta.value("lockscreenQml").toString().trimmed();

            if (id.isEmpty() || name.isEmpty() || lockQml.isEmpty()) continue;

            // Optional translation domain (defaults to extension id)
            QString translationDomain = meta.value("translationDomain").toString().trimmed();
            if (translationDomain.isEmpty()) {
                translationDomain = id;
            }

            // Register extension locale directory if present
            QString localeDir = sub.absoluteFilePath() + "/locale";
            if (QDir(localeDir).exists()) {
                KLocalizedString::addDomainLocaleDir(translationDomain.toUtf8(), localeDir);
            }

            // First found takes precedence (dev path > system path > user path)
            if (extensionsMap.contains(id)) {
                continue;
            }

            QString lockQmlPath = sub.absoluteFilePath() + "/" + lockQml;
            if (!QFile::exists(lockQmlPath)) continue;

            QString settingsQml = meta.value("settingsQml").toString().trimmed();
            QString settingsQmlPath = "";
            if (!settingsQml.isEmpty()) {
                QString fullPath = sub.absoluteFilePath() + "/" + settingsQml;
                if (QFile::exists(fullPath)) {
                    settingsQmlPath = "file://" + fullPath;
                }
            }

            QString daemon = meta.value("daemon").toString().trimmed();
            QString daemonPath = "";
            if (!daemon.isEmpty()) {
                QString fullPath = sub.absoluteFilePath() + "/" + daemon;
                if (QFile::exists(fullPath)) {
                    daemonPath = fullPath;
                }
            }

            // Resolve localized name and description
            QString sysLocale = QLocale::system().name();
            QString sysLang = sysLocale.section('_', 0, 0);

            QString resolvedName = name;
            if (meta.contains("name[" + sysLocale + "]")) {
                resolvedName = meta.value("name[" + sysLocale + "]").toString().trimmed();
            } else if (meta.contains("name[" + sysLang + "]")) {
                resolvedName = meta.value("name[" + sysLang + "]").toString().trimmed();
            } else {
                QString gettextName = ki18nd(translationDomain.toUtf8().constData(), name.toUtf8().constData()).toString();
                if (!gettextName.isEmpty()) {
                    resolvedName = gettextName;
                }
            }

            QString rawDesc = meta.value("description").toString().trimmed();
            QString resolvedDesc = rawDesc;
            if (meta.contains("description[" + sysLocale + "]")) {
                resolvedDesc = meta.value("description[" + sysLocale + "]").toString().trimmed();
            } else if (meta.contains("description[" + sysLang + "]")) {
                resolvedDesc = meta.value("description[" + sysLang + "]").toString().trimmed();
            } else if (!rawDesc.isEmpty()) {
                QString gettextDesc = ki18nd(translationDomain.toUtf8().constData(), rawDesc.toUtf8().constData()).toString();
                if (!gettextDesc.isEmpty()) {
                    resolvedDesc = gettextDesc;
                }
            }

            QJsonObject item;
            item["id"] = id;
            item["name"] = resolvedName;
            item["description"] = resolvedDesc;
            item["translationDomain"] = translationDomain;
            item["icon"] = meta.value("icon").toString().trimmed().isEmpty() ? "preferences-plugin" : meta.value("icon").toString().trimmed();
            item["version"] = meta.value("version").toString().trimmed();
            item["author"] = meta.value("author").toString().trimmed();
            item["isBuiltIn"] = sd.isBuiltIn;
            item["path"] = sub.absoluteFilePath();
            item["lockscreenQml"] = "file://" + lockQmlPath;
            item["settingsQml"] = settingsQmlPath;
            item["daemon"] = daemonPath;
            item["daemonFailed"] = failedDaemons.contains(id);
            item["defaultConfig"] = meta.value("defaultConfig").isObject() ? meta.value("defaultConfig").toObject() : QJsonObject();

            extensionsMap[id] = item;
        }
    }

    return extensionsMap;
}

inline QJsonArray getSortedExtensions() {
    auto extensionsMap = scanExtensions();
    QList<QJsonObject> extList = extensionsMap.values();

    std::sort(extList.begin(), extList.end(), [](const QJsonObject &a, const QJsonObject &b) {
        bool aBuiltIn = a.value("isBuiltIn").toBool();
        bool bBuiltIn = b.value("isBuiltIn").toBool();
        if (aBuiltIn != bBuiltIn) {
            return aBuiltIn > bBuiltIn;
        }
        return a.value("name").toString().localeAwareCompare(b.value("name").toString()) < 0;
    });

    QJsonArray result;
    for (const auto &obj : extList) {
        result.append(obj);
    }
    return result;
}

inline bool removeUserExtension(const QString &targetId) {
    const QString cleanId = targetId.trimmed();
    if (cleanId.isEmpty()) {
        return false;
    }

    const QString userExtPath = QDir::homePath() + "/.local/share/aod4kde/extensions";
    QDir rootDir(userExtPath);
    if (!rootDir.exists()) {
        return false;
    }

    const QString canonicalRoot = rootDir.canonicalPath();
    if (canonicalRoot.isEmpty()) {
        return false;
    }

    bool removedAny = false;
    const QFileInfoList subdirs = rootDir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const auto &sub : subdirs) {
        bool matches = (sub.fileName() == cleanId);

        const QString metaPath = sub.absoluteFilePath() + "/metadata.json";
        if (!matches && QFile::exists(metaPath)) {
            QFile metaFile(metaPath);
            if (metaFile.open(QIODevice::ReadOnly)) {
                QJsonParseError err;
                QJsonDocument doc = QJsonDocument::fromJson(metaFile.readAll(), &err);
                if (err.error == QJsonParseError::NoError && doc.isObject()) {
                    const QString id = doc.object().value("id").toString().trimmed();
                    if (id == cleanId) {
                        matches = true;
                    }
                }
            }
        }

        if (matches) {
            if (sub.isSymLink()) {
                if (QFile::remove(sub.absoluteFilePath())) {
                    removedAny = true;
                }
            } else {
                const QString subCanonical = sub.canonicalFilePath();
                if (!subCanonical.isEmpty() && subCanonical.startsWith(canonicalRoot + "/")) {
                    QDir dirToRemove(sub.absoluteFilePath());
                    if (dirToRemove.removeRecursively()) {
                        removedAny = true;
                    }
                }
            }
        }
    }

    return removedAny;
}

} // namespace AodCommon

