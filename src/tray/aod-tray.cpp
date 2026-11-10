#include "ExtensionSupervisor.h"
#include "../common/ConfigManager.h"

#include <QApplication>
#include <QSystemTrayIcon>
#include <QMenu>
#include <QAction>
#include <QIcon>
#include <QFileSystemWatcher>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QLockFile>
#include <QPainter>
#include <QPixmap>
#include <QProcess>
#include <QSvgRenderer>
#include <klocalizedstring.h>
#include <unistd.h>
#include <iostream>

class AodTray : public QObject {
    Q_OBJECT
public:
    explicit AodTray(QApplication *app, QObject *parent = nullptr)
        : QObject(parent), m_app(app), m_configPath(AodCommon::configPath())
    {
        m_trayIcon = new QSystemTrayIcon(this);
        m_menu = new QMenu();

        m_statusAction = m_menu->addAction("");
        m_statusAction->setEnabled(false);
        m_menu->addSeparator();

        m_toggleAction = m_menu->addAction(i18nc("@action:inmenu", "Toggle AOD"));
        connect(m_toggleAction, &QAction::triggered, this, &AodTray::toggleAod);

        QAction *settingsAction = m_menu->addAction(i18nc("@action:inmenu", "Settings…"));
        connect(settingsAction, &QAction::triggered, this, &AodTray::openSettings);

        m_menu->addSeparator();
        QAction *quitAction = m_menu->addAction(i18nc("@action:inmenu", "Quit"));
        connect(quitAction, &QAction::triggered, m_app, &QApplication::quit);

        m_trayIcon->setContextMenu(m_menu);

        connect(m_trayIcon, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
            if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::DoubleClick) {
                openSettings();
            }
        });

        m_watcher = new QFileSystemWatcher(this);
        AodCommon::ensureConfigExists(m_configPath);
        ensureWatchedPaths();

        // Supervisor for modular extensions
        m_supervisor = new ExtensionSupervisor(m_configPath, this);

        auto onStateChanged = [this](const QString &) {
            ensureWatchedPaths();
            updateStatus();
            m_supervisor->syncDaemons();
        };
        connect(m_watcher, &QFileSystemWatcher::fileChanged, this, onStateChanged);
        connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, onStateChanged);

        updateStatus();
        m_trayIcon->show();
    }

    ~AodTray() override
    {
        delete m_menu;
    }

private slots:
    void openSettings()
    {
        const QStringList candidates = {
            QCoreApplication::applicationDirPath() + "/../settings/aod-settings",
            QDir::homePath() + "/.local/bin/aod-settings",
            "/usr/local/bin/aod-settings",
            "/usr/bin/aod-settings"
        };
        QString cmd = "aod-settings";
        for (const QString &path : candidates) {
            if (QFileInfo(path).isExecutable()) {
                cmd = path;
                break;
            }
        }
        QProcess::startDetached(cmd, QStringList());
    }

    void toggleAod()
    {
        if (AodCommon::isLockscreenIncompatible()) {
            return;
        }
        bool current = AodCommon::isAodEnabled(m_configPath);
        AodCommon::setAodEnabled(!current, m_configPath);
        updateStatus();
        m_supervisor->syncDaemons();
    }

private:
    void ensureWatchedPaths()
    {
        const QStringList filePaths = {
            m_configPath,
            AodCommon::lockscreenQmlPath(),
            AodCommon::patchFailedMarkerPath()
        };
        for (const QString &fp : filePaths) {
            if (QFile::exists(fp)) {
                // Re-add path to ensure inotify watch attaches to new inode after atomic QSaveFile rename
                if (m_watcher->files().contains(fp)) {
                    m_watcher->removePath(fp);
                }
                m_watcher->addPath(fp);
            }
        }
        const QStringList dirPaths = {
            QFileInfo(m_configPath).absolutePath(),
            QFileInfo(AodCommon::lockscreenQmlPath()).absolutePath(),
            QFileInfo(AodCommon::patchFailedMarkerPath()).absolutePath()
        };
        for (const QString &dp : dirPaths) {
            if (!m_watcher->directories().contains(dp) && QDir(dp).exists()) {
                m_watcher->addPath(dp);
            }
        }
    }

    static QString findTrayIconSvgPath(bool incompatible = false)
    {
        const QString fileName = incompatible ? QStringLiteral("tray_icon_error.svg") : QStringLiteral("tray_icon.svg");
        const QStringList candidates = {
            QDir::homePath() + "/.local/share/aod4kde/assets/svg/" + fileName,
            "/usr/local/share/aod4kde/assets/svg/" + fileName,
            "/usr/share/aod4kde/assets/svg/" + fileName,
            QCoreApplication::applicationDirPath() + "/../../assets/svg/" + fileName,
            QCoreApplication::applicationDirPath() + "/../assets/svg/" + fileName,
            QCoreApplication::applicationDirPath() + "/assets/svg/" + fileName,
            QDir::currentPath() + "/assets/svg/" + fileName
        };
        for (const QString &path : candidates) {
            if (QFile::exists(path)) {
                return path;
            }
        }
        return QString();
    }

    QIcon createTrayIcon(bool enabled, bool incompatible = false) const
    {
        QPixmap pixmap(64, 64);
        pixmap.fill(Qt::transparent);

        QPainter p(&pixmap);
        p.setRenderHint(QPainter::Antialiasing);

        QSvgRenderer renderer;
        QString svgPath = findTrayIconSvgPath(incompatible);
        bool loaded = false;
        if (!svgPath.isEmpty()) {
            loaded = renderer.load(svgPath);
        }

        if (loaded) {
            p.setOpacity((incompatible || enabled) ? 1.0 : 0.45);
            renderer.render(&p, QRectF(4, 4, 56, 56));
            p.setOpacity(1.0);
        } else {
            // Fallback screen: rounded rectangle with a semi-transparent exclamation mark
            p.setOpacity((incompatible || enabled) ? 1.0 : 0.45);
            QRectF screenRect(6, 10, 52, 40);
            p.setPen(QPen(QColor("#ffffff"), 2));
            p.setBrush(QColor(0, 0, 0, 180));
            p.drawRoundedRect(screenRect, 5, 5);

            p.setPen(incompatible ? QColor("#ff0000") : QColor(255, 255, 255, 160));
            QFont f = p.font();
            f.setPixelSize(22);
            f.setBold(true);
            p.setFont(f);
            p.drawText(screenRect, Qt::AlignCenter, "!");
            p.setOpacity(1.0);
        }

        // Status indicator dot (omitted when incompatible)
        if (!incompatible) {
            p.setBrush(QColor(enabled ? "#00e676" : "#ff5252"));
            p.setPen(QPen(QColor("#000000"), 1.5));
            p.drawEllipse(46, 6, 12, 12);
        }

        p.end();
        return QIcon(pixmap);
    }

    void updateStatus()
    {
        const bool incompatible = AodCommon::isLockscreenIncompatible();
        const bool enabled = !incompatible && AodCommon::isAodEnabled(m_configPath);
        m_trayIcon->setIcon(createTrayIcon(enabled, incompatible));
        m_toggleAction->setEnabled(!incompatible);

        if (incompatible) {
            m_statusAction->setText(i18nc("@info:status", "AOD: Incompatible"));
            m_trayIcon->setToolTip(i18nc("@info:tooltip", "Always-On Display\nStatus: %1\nClick to open settings", i18nc("@info:status", "Incompatible")));
        } else {
            QString statusText = enabled ? i18nc("@info:status", "AOD: ON") : i18nc("@info:status", "AOD: OFF");
            m_statusAction->setText(statusText);
            m_trayIcon->setToolTip(i18nc("@info:tooltip", "Always-On Display\nStatus: %1\nClick to open settings", enabled ? i18nc("@info:status", "ON") : i18nc("@info:status", "OFF")));
        }
    }

    QApplication *m_app;
    QSystemTrayIcon *m_trayIcon;
    QMenu *m_menu;
    QAction *m_statusAction;
    QAction *m_toggleAction;
    QFileSystemWatcher *m_watcher;
    QString m_configPath;
    ExtensionSupervisor *m_supervisor;
};

static void setupEnvironment(uid_t uid)
{
    QString runtimeDir = QString("/run/user/%1").arg(uid);

    if (qEnvironmentVariableIsEmpty("XDG_RUNTIME_DIR") && QDir(runtimeDir).exists()) {
        qputenv("XDG_RUNTIME_DIR", runtimeDir.toUtf8());
    }
    QString dbusSock = runtimeDir + "/bus";
    if (qEnvironmentVariableIsEmpty("DBUS_SESSION_BUS_ADDRESS") && QFile::exists(dbusSock)) {
        qputenv("DBUS_SESSION_BUS_ADDRESS", QString("unix:path=" + dbusSock).toUtf8());
    }
    if (qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY")) {
        for (int i = 0; i <= 2; ++i) {
            QString wSock = QString("%1/wayland-%2").arg(runtimeDir).arg(i);
            if (QFile::exists(wSock)) {
                qputenv("WAYLAND_DISPLAY", QString("wayland-%1").arg(i).toUtf8());
                break;
            }
        }
    }
    if (qEnvironmentVariableIsEmpty("DISPLAY")) {
        qputenv("DISPLAY", ":0");
    }
}

int main(int argc, char *argv[])
{
    uid_t uid = getuid();
    setupEnvironment(uid);

    QApplication app(argc, argv);
    KLocalizedString::setApplicationDomain("aod4kde");
    app.setQuitOnLastWindowClosed(false);
    app.setApplicationName("aod-tray");
    app.setApplicationDisplayName(i18n("AOD4KDE Tray"));

    QString lockDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (lockDir.isEmpty() || !QDir(lockDir).exists()) {
        lockDir = QDir::tempPath();
    }
    QLockFile lockFile(QString("%1/aod4kde-tray-%2.lock").arg(lockDir).arg(uid));
    if (!lockFile.tryLock(100)) {
        std::cerr << i18n("aod-tray: another instance is already running. Exiting.").toStdString() << std::endl;
        return 0;
    }

    AodTray tray(&app);

    return app.exec();
}

#include "aod-tray.moc"
