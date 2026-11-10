#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QMap>
#include <QSet>
#include <QProcess>
#include <QFileSystemWatcher>
#include <QElapsedTimer>

struct DaemonRuntimeInfo {
    QProcess *proc = nullptr;
    int crashCount = 0;
    QElapsedTimer uptime;
};

class ExtensionSupervisor : public QObject {
    Q_OBJECT
public:
    explicit ExtensionSupervisor(const QString &configPath, QObject *parent = nullptr);
    ~ExtensionSupervisor() override;

public slots:
    void syncDaemons();

private:
    void startDaemon(const QString &id, const QString &execPath);
    void stopDaemon(const QString &id);
    void stopAllDaemons();
    void handleDaemonExit(const QString &id, bool isCrash);

    QString m_configPath;
    QStringList m_extDirs;
    QFileSystemWatcher *m_watcher;
    QMap<QString, DaemonRuntimeInfo> m_runningDaemons;
    QSet<QString> m_failedDaemons;
};
