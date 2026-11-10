#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusArgument>
#include <QDBusMetaType>
#include <QDBusVariant>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QString>
#include <QVariant>
#include <iostream>

static QString getUnitString(int code, const QString &sid) {
    switch(code) {
        case 1000: return "°C";
        case 1001: return "dBm";
        case 1002: return "%";
        case 1003: return "/s";
        case 1004: return "RPM";
        case 100:  return "B";
        case 101:  return "KiB";
        case 102:  return "MiB";
        case 103:  return "GiB";
        case 104:  return "TiB";
        case 200:  return "B/s";
        case 201:  return "KiB/s";
        case 202:  return "MiB/s";
        case 203:  return "GiB/s";
        case 300:  return "Hz";
        case 301:  return "kHz";
        case 302:  return "MHz";
        case 303:  return "GHz";
        case 401:  return "s";
        case 500:  return "bps";
        case 501:  return "kbps";
        case 502:  return "Mbps";
        case 503:  return "Gbps";
        case 600:  return "V";
        case 700:  return "W";
        case 800:  return "Wh";
        case 900:  return "A";
        default:   break;
    }

    if (sid.contains("Percent", Qt::CaseInsensitive) || sid.contains("usage", Qt::CaseInsensitive)) return "%";
    if (sid.contains("Temperature", Qt::CaseInsensitive) || sid.contains("temp", Qt::CaseInsensitive)) return "°C";
    return "";
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);

    QDBusInterface iface("org.kde.ksystemstats1", "/org/kde/ksystemstats1", "org.kde.ksystemstats1", QDBusConnection::sessionBus());
    if (!iface.isValid()) {
        std::cout << "[]" << std::endl;
        return 0;
    }

    QDBusMessage reply = iface.call("allSensors");
    if (reply.type() == QDBusMessage::ErrorMessage || reply.arguments().isEmpty()) {
        std::cout << "[]" << std::endl;
        return 0;
    }

    QVariant arg = reply.arguments().at(0);
    if (arg.userType() != qMetaTypeId<QDBusArgument>()) {
        std::cout << "[]" << std::endl;
        return 0;
    }

    const QDBusArgument dbusArg = arg.value<QDBusArgument>();
    QJsonArray results;

    dbusArg.beginMap();
    while (!dbusArg.atEnd()) {
        QString sid;
        QString name, shortName, description;
        int unitCode = -1;

        dbusArg.beginMapEntry();
        dbusArg >> sid;

        const QString sig = dbusArg.currentSignature();
        dbusArg.beginStructure();
        if (sig == "(sssuuddi)") {
            uint variantType = 0, u = 0;
            double min = 0.0, max = 0.0;
            int extra = 0;
            dbusArg >> name >> shortName >> description >> variantType >> u >> min >> max >> extra;
            unitCode = static_cast<int>(u);
        } else if (sig == "(sssuudd)") {
            uint variantType = 0, u = 0;
            double min = 0.0, max = 0.0;
            dbusArg >> name >> shortName >> description >> variantType >> u >> min >> max;
            unitCode = static_cast<int>(u);
        } else if (sig == "(sssvi)") {
            QDBusVariant minVar;
            dbusArg >> name >> shortName >> description >> minVar >> unitCode;
        } else {
            dbusArg >> name >> shortName >> description;
            unitCode = 0;
        }
        dbusArg.endStructure();
        dbusArg.endMapEntry();

        if (unitCode == -1 || (name.isEmpty() && shortName.isEmpty())) continue;

        QString label = !shortName.isEmpty() ? shortName : name;
        QString fullName = !name.isEmpty() ? name : shortName;
        QString unit = getUnitString(unitCode, sid);
        QString cat = sid.section('/', 0, 0).toUpper();

        QJsonObject obj;
        obj["id"] = sid;
        obj["label"] = label;
        obj["fullName"] = fullName;
        obj["category"] = cat;
        obj["unit"] = unit;

        results.append(obj);
    }
    dbusArg.endMap();

    QJsonDocument doc(results);
    std::cout << doc.toJson(QJsonDocument::Compact).toStdString() << std::endl;
    return 0;
}

