/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
*/

#include "terminallauncher.h"

#include <KConfigGroup>
#include <KService>
#include <KSharedConfig>
#include <KShell>
#include <QFile>
#include <QObject>
#include <QProcess>
#include <QStandardPaths>
#include <QStringList>

namespace
{
struct TerminalLaunchConfig {
    QString commandLine;
    QString desktopName;
    bool valid = false;
};

bool isFlatpakRuntime()
{
    static const bool flatpak = QFile::exists(QStringLiteral("/.flatpak-info"));
    return flatpak;
}

bool hostExecutableExists(const QString &executable)
{
    if (executable.isEmpty()) {
        return false;
    }

    if (!isFlatpakRuntime()) {
        return !QStandardPaths::findExecutable(executable).isEmpty();
    }

    if (QStandardPaths::findExecutable(QStringLiteral("flatpak-spawn")).isEmpty()) {
        return false;
    }

    QProcess process;

    process.start(QStringLiteral("flatpak-spawn"), {QStringLiteral("--host"), QStringLiteral("which"), executable});

    if (!process.waitForFinished(3000)) {
        process.kill();
        process.waitForFinished();
        return false;
    }

    return process.exitCode() == 0;
}

TerminalLaunchConfig buildTerminalLaunchConfig(const QString &command, const QString &workingDirectory)
{
    TerminalLaunchConfig config;

    const KConfigGroup confGroup(KSharedConfig::openConfig(), QStringLiteral("General"));
    const QString terminalExec = confGroup.readEntry("TerminalApplication");
    const QString terminalService = confGroup.readEntry("TerminalService");

    if (isFlatpakRuntime()) {
        QString exec;

        const QStringList candidates = {terminalExec, QStringLiteral("konsole"), QStringLiteral("gnome-terminal"), QStringLiteral("xterm")};

        for (const QString &candidate : candidates) {
            if (candidate.isEmpty()) {
                continue;
            }

            const QStringList parts = KShell::splitArgs(candidate);

            if (parts.isEmpty()) {
                continue;
            }

            if (!hostExecutableExists(parts.first())) {
                continue;
            }

            exec = candidate;
            break;
        }

        if (exec.isEmpty()) {
            return config;
        }

        const QStringList execParts = KShell::splitArgs(exec);
        const QString programName = execParts.isEmpty() ? QString() : execParts.first();
        const bool isKonsole = programName.startsWith(QLatin1String("konsole"));
        const bool isXterm = programName == QLatin1String("xterm");

        if (isKonsole && !workingDirectory.isEmpty()) {
            exec += QStringLiteral(" --workdir %1").arg(KShell::quoteArg(workingDirectory));
        }

        if (!command.isEmpty()) {
            if (!isKonsole && isXterm) {
                exec += QLatin1String(" -hold");
            }
            exec += QLatin1String(" -e ") + command;
        }

        config.commandLine = QStringLiteral("flatpak-spawn --host -- %1").arg(exec);
        config.valid = true;

        return config;
    }

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
bool launch(const QString &command, const QString &workingDirectory, QObject *parent, const std::function<void(bool)> &onFinished)
{
    Q_UNUSED(parent);

    const TerminalLaunchConfig config = buildTerminalLaunchConfig(command, workingDirectory);
    if (!config.valid) {
        if (onFinished) {
            auto callback = onFinished;
            callback(false);
        }
        return false;
    }

    auto *process = new QProcess();
    if (!workingDirectory.isEmpty()) {
        process->setWorkingDirectory(workingDirectory);
    }

    QObject::connect(process,
                     QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                     process,
                     [process, callback = onFinished](int exitCode, QProcess::ExitStatus exitStatus) {
                         process->deleteLater();
                         if (callback) {
                             const bool success = exitStatus == QProcess::NormalExit && exitCode == 0;
                             callback(success);
                         }
                     });

    process->startCommand(config.commandLine);
    if (!process->waitForStarted()) {
        process->deleteLater();
        if (onFinished) {
            auto callback = onFinished;
            callback(false);
        }
        return false;
    }

    return true;
}
}
