#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QTimer>
#include <csignal>
#include <unistd.h>

static QString g_runtimeFilePath;

static void cleanupFiles() {
    if (!g_runtimeFilePath.isEmpty() && QFile::exists(g_runtimeFilePath)) {
        QFile::remove(g_runtimeFilePath);
    }
}

static void signalHandler(int sig) {
    Q_UNUSED(sig);
    cleanupFiles();
    _exit(0);
}

static void updateState() {
    if (g_runtimeFilePath.isEmpty()) return;

    QJsonObject obj;
    obj["timestamp"] = QDateTime::currentDateTime().toString("HH:mm:ss");
    obj["message"] = QString("Alive at %1").arg(QDateTime::currentDateTime().toString("HH:mm:ss"));

    QJsonDocument doc(obj);
    QSaveFile file(g_runtimeFilePath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson(QJsonDocument::Compact));
        file.commit();
    }
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);

    // Termination handling for clean shutdown (aod-tray sends SIGTERM)
    std::signal(SIGTERM, signalHandler);
    std::signal(SIGINT, signalHandler);

    QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR");
    if (!runtimeDir.isEmpty() && QDir(runtimeDir).exists()) {
        g_runtimeFilePath = runtimeDir + "/aod-ext-example.json";
    } else {
        g_runtimeFilePath = QDir::tempPath() + "/aod-ext-example.json";
    }

    // Immediately write initial state
    updateState();

    // Update every 2 seconds
    QTimer timer;
    QObject::connect(&timer, &QTimer::timeout, &updateState);
    timer.start(2000);

    return app.exec();
}