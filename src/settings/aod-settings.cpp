#include <QApplication>
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QIcon>
#include <QLockFile>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include <QString>
#include <QStringList>
#include <QTemporaryFile>
#include <QUrl>
#include <QWindow>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <klocalizedstring.h>
#include <iostream>
#include <unistd.h>

#include "../common/ConfigManager.h"
#include "../common/ExtensionScanner.h"

class SettingsInstanceHandler : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "io.github.aod4kde.Settings")
public:
    explicit SettingsInstanceHandler(QQmlApplicationEngine *engine, QObject *parent = nullptr)
        : QObject(parent), m_engine(engine) {}

public slots:
    Q_SCRIPTABLE void activate() {
        if (!m_engine) return;
        const auto roots = m_engine->rootObjects();
        for (QObject *obj : roots) {
            if (auto *win = qobject_cast<QWindow *>(obj)) {
                if (win->visibility() == QWindow::Minimized) {
                    win->showNormal();
                } else {
                    win->show();
                }
                win->raise();
                win->requestActivate();

                // Also request KWin focus activation on Wayland if available
                activateViaKWin(win->title());
                break;
            }
        }
    }

private:
    static void activateViaKWin(const QString &windowTitle) {
        if (windowTitle.isEmpty()) return;
        QDBusInterface kwin("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", QDBusConnection::sessionBus());
        if (!kwin.isValid()) return;

        QTemporaryFile tmpFile(QDir::tempPath() + "/kwin_aod4kde_XXXXXX.js");
        if (!tmpFile.open()) return;

        QString escapedTitle = windowTitle;
        escapedTitle.replace("\\", "\\\\").replace("\"", "\\\"");
        const QString jsCode = QStringLiteral(
            "var clients = workspace.windowList();\n"
            "for (var i = 0; i < clients.length; i++) {\n"
            "    var c = clients[i];\n"
            "    if (c.caption && (c.caption.indexOf(\"%1\") !== -1 || c.resourceName === \"aod-settings\")) {\n"
            "        if (c.minimized) c.minimized = false;\n"
            "        workspace.activeWindow = c;\n"
            "        break;\n"
            "    }\n"
            "}\n"
        ).arg(escapedTitle);

        tmpFile.write(jsCode.toUtf8());
        tmpFile.flush();

        const QString scriptFilePath = tmpFile.fileName();
        QDBusReply<int> reply = kwin.call("loadScript", scriptFilePath);
        if (reply.isValid()) {
            int scriptId = reply.value();
            const QString scriptPath = QString("/Scripting/Script%1").arg(scriptId);
            QDBusInterface scriptIface("org.kde.KWin", scriptPath, "org.kde.kwin.Script", QDBusConnection::sessionBus());
            scriptIface.call("run");
            scriptIface.call("stop");
        }
    }

    QQmlApplicationEngine *m_engine;
};

static void registerExtensionLocales(const QString &appDir) {
    QByteArray xdgDataDirs = qgetenv("XDG_DATA_DIRS");
    if (xdgDataDirs.isEmpty()) {
        xdgDataDirs = "/usr/local/share:/usr/share";
    }

    const QStringList extRoots = {
        appDir + "/../extensions",
        QDir::homePath() + "/.local/share/aod4kde/extensions",
        "/usr/local/share/aod4kde/extensions",
        "/usr/share/aod4kde/extensions"
    };

    QStringList prependDirs;
    for (const QString &root : extRoots) {
        QDir dir(root);
        if (!dir.exists()) continue;
        const QFileInfoList subdirs = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QFileInfo &sub : subdirs) {
            const QString localeDir = sub.absoluteFilePath() + "/locale";
            if (QDir(localeDir).exists()) {
                prependDirs.append(sub.absoluteFilePath());
                KLocalizedString::addDomainLocaleDir(sub.fileName().toUtf8(), localeDir);
            }
        }
    }

    if (!prependDirs.isEmpty()) {
        qputenv("XDG_DATA_DIRS", prependDirs.join(':').toUtf8() + ":" + xdgDataDirs);
    }
}

static QString findMainQmlPath(const QString &appDir) {
    const QStringList candidates = {
        appDir + "/aod-config.qml",
        appDir + "/../settings/aod-config.qml",
        QDir::homePath() + "/.local/share/aod4kde/aod-config.qml",
        "/usr/local/share/aod4kde/aod-config.qml",
        "/usr/share/aod4kde/aod-config.qml"
    };

    for (const QString &candidate : candidates) {
        QFileInfo fi(candidate);
        if (fi.exists() && fi.isFile()) {
            return fi.canonicalFilePath();
        }
    }
    return QString();
}

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    KLocalizedString::setApplicationDomain("aod4kde");
    app.setApplicationName("aod-settings");
    app.setApplicationDisplayName(i18n("AOD4KDE Settings"));
    app.setDesktopFileName("aod-settings");
    app.setWindowIcon(QIcon::fromTheme("preferences-desktop-display"));

    const QString dbusService = QStringLiteral("io.github.aod4kde.Settings");
    const QString dbusPath = QStringLiteral("/Settings");

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        if (!bus.registerService(dbusService)) {
            QDBusMessage msg = QDBusMessage::createMethodCall(
                dbusService, dbusPath, QStringLiteral("io.github.aod4kde.Settings"), QStringLiteral("activate"));
            bus.call(msg, QDBus::NoBlock);
            return 0;
        }
    }

    // Fallback kernel lock file in case D-Bus session bus is unavailable
    QString runDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (runDir.isEmpty() || !QDir(runDir).exists()) {
        runDir = QDir::tempPath();
    }
    QLockFile lockFile(QString("%1/aod4kde-settings-%2.lock").arg(runDir).arg(getuid()));
    if (!lockFile.tryLock(100)) {
        return 0;
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    registerExtensionLocales(appDir);

    const QString qmlPath = findMainQmlPath(appDir);
    if (qmlPath.isEmpty()) {
        std::cerr << "aod-settings: cannot find aod-config.qml" << std::endl;
        return 1;
    }

    QQmlApplicationEngine engine;
    SettingsInstanceHandler instanceHandler(&engine);
    if (bus.isConnected()) {
        bus.registerObject(dbusPath, &instanceHandler, QDBusConnection::ExportScriptableSlots);
    }

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(1); }, Qt::QueuedConnection);

    // Pre-load configuration, hardware state, and extensions for instant UI presentation
    AodCommon::ensureConfigExists();
    QJsonObject cfg = AodCommon::loadConfig();
    if (cfg.isEmpty()) {
        const QStringList fallbackCandidates = {
            QDir::homePath() + "/.local/share/aod4kde/default-config.json",
            "/usr/local/share/aod4kde/default-config.json",
            "/usr/share/aod4kde/default-config.json",
            appDir + "/default-config.json",
            appDir + "/../settings/default-config.json"
        };
        for (const QString &fallbackPath : fallbackCandidates) {
            cfg = AodCommon::loadConfig(fallbackPath);
            if (!cfg.isEmpty()) {
                break;
            }
        }
    }

    const bool hasBattery = AodCommon::hasSystemBattery();
    if (!hasBattery) {
        cfg[QStringLiteral("showBattery")] = false;
    }
    const QJsonArray extensions = AodCommon::getSortedExtensions();
    const bool isIncompatible = AodCommon::isLockscreenIncompatible();

    QQmlContext *rootCtx = engine.rootContext();
    const QString initialConfigJson = QString::fromUtf8(QJsonDocument(cfg).toJson(QJsonDocument::Compact));
    const QString initialExtensionsJson = QString::fromUtf8(QJsonDocument(extensions).toJson(QJsonDocument::Compact));
    rootCtx->setContextProperty(QStringLiteral("initialConfigJson"), initialConfigJson);
    rootCtx->setContextProperty(QStringLiteral("initialExtensionsJson"), initialExtensionsJson);
    rootCtx->setContextProperty(QStringLiteral("initialHasBattery"), hasBattery);
    rootCtx->setContextProperty(QStringLiteral("initialIsIncompatible"), isIncompatible);

    engine.load(QUrl::fromLocalFile(qmlPath));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }

    return app.exec();
}

#include "aod-settings.moc"

