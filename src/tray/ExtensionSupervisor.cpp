#include "ExtensionSupervisor.h"
#include "../common/ConfigManager.h"
#include "../common/ExtensionScanner.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonObject>
#include <QSet>
#include <QTimer>
#include <QDebug>
#include <filesystem>
#include <system_error>

ExtensionSupervisor::ExtensionSupervisor(const QString &configPath, QObject *parent)
    : QObject(parent), m_configPath(configPath)
{
    m_failedDaemons = AodCommon::loadFailedDaemons();
    const auto searchDirs = AodCommon::getExtensionSearchDirs();
    for (const auto &sd : searchDirs) {
        if (!sd.isBuiltIn) {
            std::error_code ec;
            std::filesystem::create_directories(sd.path.toStdString(), ec);
        }
        m_extDirs << sd.path;
    }

    m_watcher = new QFileSystemWatcher(this);
    for (const QString &d : m_extDirs) {
        if (QDir(d).exists()) {
            m_watcher->addPath(d);
        }
    }

    const QString failuresFile = AodCommon::daemonFailuresPath();
    const QString failuresDir = QFileInfo(failuresFile).absolutePath();
    if (QDir(failuresDir).exists()) {
        m_watcher->addPath(failuresDir);
    }
    if (QFile::exists(failuresFile)) {
        m_watcher->addPath(failuresFile);
    }

    auto onWatchedChanged = [this](const QString &) {
        const QString fPath = AodCommon::daemonFailuresPath();
        if (QFile::exists(fPath) && !m_watcher->files().contains(fPath)) {
            m_watcher->addPath(fPath);
        }
        syncDaemons();
    };

    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, onWatchedChanged);
    connect(m_watcher, &QFileSystemWatcher::fileChanged, this, onWatchedChanged);

    syncDaemons();
}

ExtensionSupervisor::~ExtensionSupervisor()
{
    stopAllDaemons();
}

void ExtensionSupervisor::syncDaemons()
{
    m_failedDaemons = AodCommon::loadFailedDaemons();
    const QJsonObject configObj = AodCommon::loadConfig(m_configPath);
    const bool aodGloballyEnabled = !AodCommon::isLockscreenIncompatible() && configObj.value("enabled").toBool(true);
    const QJsonObject extensionsConfig = configObj.value("extensions").toObject();

    // 1. Find all extensions with a valid daemon via unified scanner
    QMap<QString, QString> availableDaemons; // id -> executable path
    auto allExtensions = AodCommon::scanExtensions();
    for (auto it = allExtensions.begin(); it != allExtensions.end(); ++it) {
        QString daemon = it.value().value("daemon").toString().trimmed();
        if (!daemon.isEmpty() && QFile::exists(daemon)) {
            availableDaemons[it.key()] = daemon;
        }
    }

    // 2. Determine which daemons should be running
    QSet<QString> shouldRun;
    if (aodGloballyEnabled) {
        for (auto it = availableDaemons.begin(); it != availableDaemons.end(); ++it) {
            const QString &id = it.key();
            bool enabled = false;
            if (extensionsConfig.contains(id)) {
                enabled = extensionsConfig.value(id).toObject().value("enabled").toBool(false);
            }
            if (enabled && !m_failedDaemons.contains(id)) {
                shouldRun.insert(id);
            }
        }
    }

    // 3. Stop daemons that are no longer needed (disabled, AOD turned off, or marked failed)
    QStringList toStop;
    for (auto it = m_runningDaemons.begin(); it != m_runningDaemons.end(); ++it) {
        if (!shouldRun.contains(it.key())) {
            toStop.append(it.key());
        }
    }
    for (const QString &id : toStop) {
        stopDaemon(id);
    }

    // 4. Start enabled daemons not currently running
    for (const QString &id : shouldRun) {
        if (!m_runningDaemons.contains(id)) {
            startDaemon(id, availableDaemons[id]);
        }
    }
}

void ExtensionSupervisor::startDaemon(const QString &id, const QString &execPath)
{
    if (m_failedDaemons.contains(id)) {
        return;
    }

    QFileInfo fi(execPath);
    if (!fi.exists() || !fi.isExecutable()) {
        qWarning() << "AOD4KDE: Extension daemon" << id << "is not executable or missing:" << execPath;
        m_failedDaemons.insert(id);
        AodCommon::saveFailedDaemons(m_failedDaemons);
        return;
    }

    QProcess *proc = new QProcess(this);
    proc->setProcessChannelMode(QProcess::ForwardedErrorChannel);

    connect(proc, &QProcess::errorOccurred, this, [this, id](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            qWarning() << "AOD4KDE: Extension daemon" << id << "failed to start.";
            handleDaemonExit(id, true);
        }
    });

    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, id](int exitCode, QProcess::ExitStatus exitStatus) {
        handleDaemonExit(id, exitStatus == QProcess::CrashExit || exitCode != 0);
    });

    DaemonRuntimeInfo info;
    info.proc = proc;
    if (m_runningDaemons.contains(id)) {
        info.crashCount = m_runningDaemons[id].crashCount;
    }
    info.uptime.start();
    m_runningDaemons[id] = info;

    proc->start(execPath, QStringList());
}

void ExtensionSupervisor::handleDaemonExit(const QString &id, bool isCrash)
{
    if (!m_runningDaemons.contains(id)) return;

    DaemonRuntimeInfo info = m_runningDaemons.take(id);
    if (info.proc) {
        info.proc->disconnect(this);
        info.proc->deleteLater();
    }

    if (isCrash) {
        if (info.uptime.isValid() && info.uptime.elapsed() > 60000) {
            info.crashCount = 0;
        }
        info.crashCount++;

        if (info.crashCount >= 5) {
            qWarning() << "AOD4KDE: Extension daemon" << id << "exceeded crash limit (5). Marking as failed.";
            m_failedDaemons.insert(id);
            AodCommon::saveFailedDaemons(m_failedDaemons);
            return;
        }

        m_runningDaemons[id] = info;
        int delay = qMin(2000 * info.crashCount, 10000);
        QTimer::singleShot(delay, this, &ExtensionSupervisor::syncDaemons);
    } else {
        info.crashCount = 0;
        m_runningDaemons.remove(id);
    }
}

void ExtensionSupervisor::stopDaemon(const QString &id)
{
    if (!m_runningDaemons.contains(id)) return;
    DaemonRuntimeInfo info = m_runningDaemons.take(id);
    if (info.proc) {
        info.proc->disconnect(this);
        info.proc->terminate();
        if (!info.proc->waitForFinished(500)) {
            info.proc->kill();
            info.proc->waitForFinished(200);
        }
        info.proc->deleteLater();
    }
}

void ExtensionSupervisor::stopAllDaemons()
{
    const QStringList ids = m_runningDaemons.keys();
    for (const QString &id : ids) {
        stopDaemon(id);
    }
}
