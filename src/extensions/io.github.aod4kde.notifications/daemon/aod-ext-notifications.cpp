#include <QGuiApplication>
#include <QIcon>
#include <QProcess>
#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDir>
#include <QMap>
#include <QStringList>
#include <QTimer>
#include <csignal>
#include <unistd.h>
#include <iostream>

static QString g_primaryPath;
static QString g_fallbackPath;

static void cleanupFiles() {
    if (!g_primaryPath.isEmpty() && QFile::exists(g_primaryPath)) {
        QFile::remove(g_primaryPath);
    }
    if (!g_fallbackPath.isEmpty() && g_fallbackPath != g_primaryPath && QFile::exists(g_fallbackPath)) {
        QFile::remove(g_fallbackPath);
    }
}

static void signalHandler(int sig) {
    cleanupFiles();
    _exit(0);
}

struct PendingNotification {
    QString icon;
    QString appName;
    uint replacesId;
};

class NotificationMonitor : public QObject {
    Q_OBJECT
public:
    explicit NotificationMonitor(QObject *parent = nullptr) : QObject(parent), m_proc(nullptr) {
        determineOutputPaths();
        saveNotificationsState(); // Inizializza stato vuoto

        m_reconnectTimer = new QTimer(this);
        m_reconnectTimer->setSingleShot(true);
        connect(m_reconnectTimer, &QTimer::timeout, this, &NotificationMonitor::startMonitor);

        startMonitor();
    }

    ~NotificationMonitor() override {
        stopMonitor();
        cleanupFiles();
    }

private slots:
    void onReadyRead() {
        if (!m_proc) return;
        m_buffer.append(m_proc->readAllStandardOutput());
        while (true) {
            int idx = m_buffer.indexOf('\n');
            if (idx == -1) break;
            QByteArray line = m_buffer.left(idx).trimmed();
            m_buffer.remove(0, idx + 1);
            if (!line.isEmpty()) {
                parseDbusLine(line);
            }
        }
    }

    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitCode);
        Q_UNUSED(exitStatus);
        if (!m_reconnectTimer->isActive()) {
            m_reconnectTimer->start(2000);
        }
    }

private:
    void determineOutputPaths() {
        QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR");
        if (runtimeDir.isEmpty()) {
            runtimeDir = QString("/run/user/%1").arg(getuid());
        }
        if (QDir(runtimeDir).exists()) {
            m_primaryPath = runtimeDir + "/aod-notifications.json";
        } else {
            m_primaryPath = QDir::homePath() + "/.cache/aod-notifications.json";
        }
        m_fallbackPath = QDir::homePath() + "/.cache/aod-notifications.json";

        g_primaryPath = m_primaryPath;
        g_fallbackPath = m_fallbackPath;
    }

    void startMonitor() {
        stopMonitor();

        m_proc = new QProcess(this);
        connect(m_proc, &QProcess::readyReadStandardOutput, this, &NotificationMonitor::onReadyRead);
        connect(m_proc, &QProcess::readyReadStandardError, this, [this]() {
            if (m_proc) {
                std::cerr << "[aod-ext-notifications busctl err] " << m_proc->readAllStandardError().toStdString() << std::endl;
            }
        });
        connect(m_proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, &NotificationMonitor::onProcessFinished);

        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        uid_t uid = getuid();
        if (env.value("DBUS_SESSION_BUS_ADDRESS").isEmpty()) {
            env.insert("DBUS_SESSION_BUS_ADDRESS", QString("unix:path=/run/user/%1/bus").arg(uid));
        }
        if (env.value("XDG_RUNTIME_DIR").isEmpty()) {
            env.insert("XDG_RUNTIME_DIR", QString("/run/user/%1").arg(uid));
        }
        m_proc->setProcessEnvironment(env);

        QStringList args;
        args << "--user" << "--json=short" << "monitor" << "org.freedesktop.Notifications";
        m_proc->start("busctl", args);
    }

    void stopMonitor() {
        if (m_proc) {
            m_proc->disconnect(this);
            m_proc->terminate();
            if (!m_proc->waitForFinished(500)) {
                m_proc->kill();
                m_proc->waitForFinished(200);
            }
            delete m_proc;
            m_proc = nullptr;
        }
        m_buffer.clear();
        m_pendingNotify.clear();
    }

    QString resolveThemeIcon(const QString &candidate) {
        if (candidate.isEmpty()) return "";

        if (!candidate.endsWith("-symbolic")) {
            QString sym = candidate + "-symbolic";
            if (QIcon::hasThemeIcon(sym)) return sym;
        } else if (QIcon::hasThemeIcon(candidate)) {
            return candidate;
        }

        QStringList fallbacks;
        QString low = candidate.toLower();
        if (low == "telegram" || low == "telegram-desktop" || low == "telegramdesktop") {
            fallbacks << "org.telegram.desktop-symbolic" << "telegram-panel-symbolic" << "telegram-symbolic"
                      << "org.telegram.desktop" << "telegram-panel" << "telegram";
        } else if (low == "firefox") {
            fallbacks << "firefox-symbolic" << "firefox";
        } else if (low == "waterfox") {
            fallbacks << "net.waterfox.waterfox-symbolic" << "waterfox-symbolic"
                      << "net.waterfox.waterfox" << "waterfox";
        } else if (low == "chrome" || low == "google-chrome") {
            fallbacks << "google-chrome-symbolic" << "com.google.Chrome-symbolic"
                      << "com.google.Chrome" << "google-chrome" << "chromium";
        } else if (low == "discord") {
            fallbacks << "com.discordapp.Discord-symbolic" << "discord-symbolic"
                      << "com.discordapp.Discord" << "discord";
        } else if (low == "spectacle") {
            fallbacks << "spectacle-symbolic" << "org.kde.spectacle-symbolic" << "spectacle";
        }

        for (const QString &fb : fallbacks) {
            if (QIcon::hasThemeIcon(fb)) return fb;
        }

        if (QIcon::hasThemeIcon(candidate)) return candidate;

        if (candidate.endsWith("-symbolic")) {
            QString stripped = candidate.left(candidate.length() - 9);
            if (QIcon::hasThemeIcon(stripped)) return stripped;
        }

        return candidate;
    }

    QString sanitizeIcon(const QString &appName, const QString &appIcon, const QJsonObject &hints) {
        QString candidate;
        if (!appIcon.trimmed().isEmpty()) {
            candidate = appIcon.trimmed();
        } else if (hints.contains("desktop-entry")) {
            QString de = hints.value("desktop-entry").toObject().value("data").toString().trimmed();
            if (!de.isEmpty()) {
                if (de.endsWith(".desktop", Qt::CaseInsensitive)) de.chop(8);
                candidate = de;
            }
        } else if (hints.contains("image-path")) {
            QString ip = hints.value("image-path").toObject().value("data").toString().trimmed();
            if (!ip.isEmpty()) candidate = ip;
        }

        if (candidate.isEmpty()) {
            QString clean = appName.trimmed().toLower();
            clean.replace(" ", "-");
            candidate = clean;
        }

        QString resolved = resolveThemeIcon(candidate);
        if (!resolved.isEmpty()) return resolved;

        return "preferences-desktop-notification";
    }

    static QString makeCallKey(const QString &peer, qint64 cookie) {
        if (!peer.isEmpty()) {
            return peer + QLatin1Char(':') + QString::number(cookie);
        }
        return QString::number(cookie);
    }

    void parseDbusLine(const QByteArray &line) {
        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(line, &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject()) return;

        QJsonObject obj = doc.object();
        QString type = obj.value("type").toString();
        QString member = obj.value("member").toString();
        QString sender = obj.value("sender").toString();
        QString destination = obj.value("destination").toString();
        QJsonObject payload = obj.value("payload").toObject();
        QJsonArray data = payload.value("data").toArray();

        if (type == "method_call" && member == "Notify") {
            qint64 cookie = obj.value("cookie").toInteger();
            QString appName = data.size() > 0 ? data.at(0).toString() : "";
            uint replacesId = data.size() > 1 ? static_cast<uint>(data.at(1).toInteger()) : 0;
            QString appIcon = data.size() > 2 ? data.at(2).toString() : "";
            QJsonObject hints = data.size() > 6 ? data.at(6).toObject() : QJsonObject();

            QString icon = sanitizeIcon(appName, appIcon, hints);
            if (replacesId > 0) {
                m_activeNotifications.remove(replacesId);
            }
            QString key = makeCallKey(sender, cookie);
            m_pendingNotify[key] = { icon, appName, replacesId };

            // Cap queue size to prevent unbounded memory growth if replies are dropped
            if (m_pendingNotify.size() > 100) {
                m_pendingNotify.remove(m_pendingNotify.firstKey());
            }
        }
        else if (type == "method_return") {
            qint64 replyCookie = obj.value("reply_cookie").toInteger();
            QString key = makeCallKey(destination, replyCookie);
            if (!m_pendingNotify.contains(key)) {
                key = QString::number(replyCookie);
            }
            if (m_pendingNotify.contains(key)) {
                PendingNotification info = m_pendingNotify.take(key);
                if (!data.isEmpty()) {
                    uint newId = static_cast<uint>(data.at(0).toInteger());
                    if (newId > 0) {
                        m_activeNotifications[newId] = info.icon;
                        saveNotificationsState();
                    }
                }
            }
        }
        else if (type == "error") {
            qint64 replyCookie = obj.value("reply_cookie").toInteger();
            m_pendingNotify.remove(makeCallKey(destination, replyCookie));
            m_pendingNotify.remove(QString::number(replyCookie));
        }
        else if (member == "NotificationClosed") {
            uint id = data.size() > 0 ? static_cast<uint>(data.at(0).toInteger()) : 0;
            if (m_activeNotifications.remove(id) > 0) {
                saveNotificationsState();
            }
        }
        else if (member == "CloseNotification") {
            uint id = data.size() > 0 ? static_cast<uint>(data.at(0).toInteger()) : 0;
            if (m_activeNotifications.remove(id) > 0) {
                saveNotificationsState();
            }
        }
    }

    void saveNotificationsState() {
        QStringList uniqueIcons;
        for (const QString &icon : m_activeNotifications.values()) {
            if (!icon.isEmpty() && !uniqueIcons.contains(icon)) {
                uniqueIcons.append(icon);
            }
        }

        QJsonObject root;
        QJsonArray iconsArr;
        for (const QString &icon : uniqueIcons) {
            iconsArr.append(icon);
        }
        root["icons"] = iconsArr;
        root["count"] = iconsArr.size();

        QJsonDocument doc(root);
        QByteArray jsonBytes = doc.toJson(QJsonDocument::Compact);

        auto writeFile = [](const QString &path, const QByteArray &data) {
            QSaveFile file(path);
            if (file.open(QIODevice::WriteOnly)) {
                file.write(data);
                file.commit();
            }
        };

        if (!m_primaryPath.isEmpty()) {
            writeFile(m_primaryPath, jsonBytes);
        }
        if (!m_fallbackPath.isEmpty() && m_fallbackPath != m_primaryPath) {
            writeFile(m_fallbackPath, jsonBytes);
        }
    }

    QProcess *m_proc;
    QByteArray m_buffer;
    QTimer *m_reconnectTimer;
    QString m_primaryPath;
    QString m_fallbackPath;
    QMap<QString, PendingNotification> m_pendingNotify;
    QMap<uint, QString> m_activeNotifications;
};

int main(int argc, char *argv[]) {
    // Clean signal handling
    std::signal(SIGTERM, signalHandler);
    std::signal(SIGINT, signalHandler);

    // If no graphical display is specified, use offscreen
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM") && qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY") && qEnvironmentVariableIsEmpty("DISPLAY")) {
        qputenv("QT_QPA_PLATFORM", "offscreen");
    }

    QGuiApplication app(argc, argv);
    app.setApplicationName("aod-ext-notifications");

    NotificationMonitor monitor;

    return app.exec();
}

#include "aod-ext-notifications.moc"

