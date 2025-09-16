/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
*/

#include "terminallauncher.h"

#include <KConfigGroup>
#include <KIO/CommandLauncherJob>
#include <KJob>
#include <KService>
#include <KSharedConfig>
#include <KShell>
#include <QEventLoop>
#include <QObject>
#include <QStandardPaths>

namespace
{
struct TerminalLaunchConfig {
    QString commandLine;
    QString desktopName;
    bool valid = false;
};

TerminalLaunchConfig buildTerminalLaunchConfig(const QString &command, const QString &workingDirectory)
{
    TerminalLaunchConfig config;

    const KConfigGroup confGroup(KSharedConfig::openConfig(), QStringLiteral("General"));
    const QString terminalExec = confGroup.readEntry("TerminalApplication");
    const QString terminalService = confGroup.readEntry("TerminalService");

    KService::Ptr service;
    if (!terminalService.isEmpty()) {
        service = KService::serviceByStorageId(terminalService);
    } else if (!terminalExec.isEmpty()) {
        service = KService::Ptr(new KService(QStringLiteral("terminal"), terminalExec, QStringLiteral("utilities-terminal")));
    }

    if (!service) {
        service = KService::serviceByStorageId(QStringLiteral("org.kde.konsole"));
    }

    QString exec;
    if (service) {
        config.desktopName = service->desktopEntryName();
        exec = service->exec();
    }

    auto useIfAvailable = [&exec](const QString &terminalApp) {
        if (!QStandardPaths::findExecutable(terminalApp).isEmpty()) {
            exec = terminalApp;
            return true;
        }
        return false;
    };

    if (exec.isEmpty()) {
        if (!useIfAvailable(QStringLiteral("konsole")) && !useIfAvailable(QStringLiteral("xterm"))) {
            return config;
        }
    }

    const bool isKonsole = exec.startsWith(QLatin1String("konsole")) || config.desktopName == QStringLiteral("org.kde.konsole");

    if (isKonsole && !workingDirectory.isEmpty()) {
        exec += QStringLiteral(" --workdir %1").arg(KShell::quoteArg(workingDirectory));
    }

    if (!command.isEmpty()) {
        if (!isKonsole && exec == QLatin1String("xterm")) {
            exec += QLatin1String(" -hold");
        }
        exec += QLatin1String(" -e ") + command;
    }

    config.commandLine = exec;
    config.valid = true;
    return config;
}
}

namespace TerminalLauncher
{
bool launch(const QString &command, const QString &workingDirectory, QObject *parent)
{
    const TerminalLaunchConfig config = buildTerminalLaunchConfig(command, workingDirectory);
    if (!config.valid) {
        return false;
    }

    auto *job = new KIO::CommandLauncherJob(config.commandLine, parent);
    if (!config.desktopName.isEmpty()) {
        job->setDesktopName(config.desktopName);
    }
    if (!workingDirectory.isEmpty()) {
        job->setWorkingDirectory(workingDirectory);
    }

    bool success = false;
    QEventLoop loop;
    QObject::connect(job, &KJob::result, &loop, [&loop, &success](KJob *finishedJob) {
        success = finishedJob->error() == KJob::NoError;
        finishedJob->deleteLater();
        loop.quit();
    });

    job->start();
    loop.exec();

    return success;
}
}
