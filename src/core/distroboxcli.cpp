/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
*/

#include "distroboxcli.h"

#include <QEventLoop>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>

using namespace Qt::Literals::StringLiterals;

namespace
{
bool isFlatpakRuntime()
{
    return QFile::exists(u"/.flatpak-info"_s);
}
}

namespace DistroboxCli
{
QString runCommand(const QString &command, bool &success)
{
    QString actualCommand = u"/usr/bin/env "_s + command;
    if (isFlatpakRuntime()) {
        actualCommand = u"flatpak-spawn --host /usr/bin/env "_s + command;
    }
    qDebug() << "Actual command:" << actualCommand;

    QString output;
    QProcess process;
    QObject::connect(&process, &QProcess::finished, [&process, &output, &success](int exitCode, QProcess::ExitStatus) {
        output = QString::fromUtf8(process.readAllStandardOutput());
        success = (exitCode == 0);
    });

    QEventLoop loop;
    QObject::connect(&process, &QProcess::finished, &loop, &QEventLoop::quit);

    process.start(u"sh"_s, QStringList() << QLatin1String("-c") << actualCommand);
    loop.exec();

    return output;
}

AvailableImages availableImages()
{
    bool success = false;
    const QString output = runCommand(u"distrobox create -C"_s, success);
    if (!success) {
        return {};
    }

    QStringList lines = output.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts);
    if (!lines.isEmpty() && lines.first().trimmed().isEmpty()) {
        lines.removeFirst();
    }

    AvailableImages images;
    images.displayNames = lines;
    images.fullNames = lines;
    return images;
}

QString containersJson()
{
    bool success = false;
    const QString namesOutput = runCommand(u"distrobox list | tail -n +2 | cut -d'|' -f2 | awk '{$1=$1;print}'"_s, success);
    if (!success) {
        return u"[]"_s;
    }

    const QString imagesOutput = runCommand(u"distrobox list | tail -n +2 | cut -d'|' -f4 | awk '{$1=$1;print}'"_s, success);
    if (!success) {
        return u"[]"_s;
    }

    const QStringList names = namesOutput.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts);
    const QStringList images = imagesOutput.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts);

    QJsonArray containerArray;
    for (int i = 0; i < qMin(names.size(), images.size()); ++i) {
        QJsonObject container;
        container[u"name"_s] = names[i];
        container[u"image"_s] = images[i];
        containerArray.append(container);
    }

    return QString::fromUtf8(QJsonDocument(containerArray).toJson());
}

QString availableImagesJson(const AvailableImages &images)
{
    if (images.displayNames.isEmpty() || images.fullNames.isEmpty()) {
        return u"[]"_s;
    }

    QJsonArray imageArray;
    for (int i = 0; i < images.displayNames.size() && i < images.fullNames.size(); ++i) {
        QJsonObject image;
        image[u"display"_s] = images.displayNames[i];
        image[u"full"_s] = images.fullNames[i];
        imageArray.append(image);
    }

    return QString::fromUtf8(QJsonDocument(imageArray).toJson());
}

bool isFlatpak()
{
    return isFlatpakRuntime();
}
}
