/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
    SPDX-FileCopyrightText: 2025 Hadi Chokr <hadichokr@icloud.com>
*/

#include "terminallauncher.h"

#include <KConfigGroup>
#include <KIO/CommandLauncherJob>
#include <KJob>
#include <KService>
#include <KSharedConfig>
#include <KShell>
#include <QEventLoop>
#include <QFile>
#include <QObject>
#include <QProcess>
#include <QStandardPaths>
#include <QStringList>

namespace TerminalLauncher
{

const QMap<QString, TerminalSpec> terminalSpecs = {
    {"konsole",      {"konsole",      {"--workdir", "$workdir", "-e", "$command"}}},
    {"xterm",        {"xterm",        {"-hold", "-e", "$command"}}},
    {"gnome-terminal", {"gnome-terminal", {"--", "$command"}}},
    {"xfce4-terminal", {"xfce4-terminal", {"--command=$command"}}},
    {"kgx",          {"kgx",          {"-e", "$command"}}},
    {"tilix",        {"tilix",        {"-e", "$command"}}},
    {"alacritty",    {"alacritty",    {"-e", "$command"}}},
    {"kitty",        {"kitty",        {"-e", "$command"}}},
    {"terminator",   {"terminator",   {"-e", "$command"}}},
    {"urxvt",        {"urxvt",        {"-e", "$command"}}},
    {"lxterminal",   {"lxterminal",   {"-e", "$command"}}},
    {"eterm",        {"eterm",        {"-e", "$command"}}},
    {"st",           {"st",           {"-e", "$command"}}},
    {"wezterm",      {"wezterm",      {"-e", "$command"}}},
    {"ptyxis",       {"ptyxis",       {"-x", "$command"}}},

    // Flatpak variants
    {"org.contourterminal.Contour", {"contour", {"run", "$terminal", "--", "/bin/bash", "-c", "$command"}}},
    {"org.wezfurlong.wezterm",      {"wezterm", {"run", "$terminal", "-e", "/bin/bash", "-c", "$command"}}},
    {"org.kde.konsole",             {"konsole", {"run", "$terminal", "-e", "/bin/bash", "-c", "$command"}}}
};

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
    process.start(QStringLiteral("flatpak-spawn"),
                  {QStringLiteral("--host"), QStringLiteral("which"), executable});

    if (!process.waitForFinished(3000)) {
        process.kill();
        process.waitForFinished();
        return false;
    }

    return process.exitCode() == 0;
}

QStringList expandArgs(const QStringList &templateArgs,
                       const QString &command,
                       const QString &workdir)
{
    QStringList args;
    for (QString arg : templateArgs) {
        arg.replace("$command", command);
        arg.replace("$workdir", workdir);
        args << arg;
    }
    return args;
}

TerminalLaunchConfig buildTerminalLaunchConfig(const QString &command, const QString &workingDirectory)
{
    TerminalLaunchConfig config;

    const KConfigGroup confGroup(KSharedConfig::openConfig(), QStringLiteral("General"));
    const QString terminalExec = confGroup.readEntry("TerminalApplication");
    const QString terminalService = confGroup.readEntry("TerminalService");

    QString chosenExec = terminalExec;
    QString desktopName;

    if (isFlatpakRuntime()) {
        // Flatpak: try configured terminal, else fall back through known candidates
        QStringList candidates = {terminalExec, QStringLiteral("konsole"),
                                  QStringLiteral("gnome-terminal"), QStringLiteral("xterm")};

        for (const QString &candidate : candidates) {
            if (candidate.isEmpty()) {
                continue;
            }
            QStringList parts = KShell::splitArgs(candidate);
            if (parts.isEmpty()) {
                continue;
            }
            if (!hostExecutableExists(parts.first())) {
                continue;
            }
            chosenExec = candidate;
            break;
        }

        if (chosenExec.isEmpty()) {
            return config;
        }
    } else {
        // Native: use TerminalService or TerminalApplication or fallback
        KService::Ptr service;
        if (!terminalService.isEmpty()) {
            service = KService::serviceByStorageId(terminalService);
        } else if (!terminalExec.isEmpty()) {
            service = KService::Ptr(new KService(QStringLiteral("terminal"), terminalExec,
                                                 QStringLiteral("utilities-terminal")));
        }

        if (!service) {
            service = KService::serviceByStorageId(QStringLiteral("org.kde.konsole"));
        }

        if (service) {
            desktopName = service->desktopEntryName();
            chosenExec = service->exec();
        }

        if (chosenExec.isEmpty()) {
            // fallback to konsole/xterm
            if (!QStandardPaths::findExecutable(QStringLiteral("konsole")).isEmpty()) {
                chosenExec = QStringLiteral("konsole");
            } else if (!QStandardPaths::findExecutable(QStringLiteral("xterm")).isEmpty()) {
                chosenExec = QStringLiteral("xterm");
            } else {
                return config;
            }
        }
    }

    // Build args
    QString baseExec = chosenExec.section(' ', 0, 0);
    QString restArgs = chosenExec.section(' ', 1);

    if (!terminalSpecs.contains(baseExec)) {
        return config;
    }

    TerminalSpec spec = terminalSpecs.value(baseExec);
    QStringList args = expandArgs(spec.argsTemplate, command, workingDirectory);

    QString fullCommandLine = spec.executable;
    if (!restArgs.isEmpty()) {
        fullCommandLine += QLatin1Char(' ') + restArgs;
    }
    if (!args.isEmpty()) {
        fullCommandLine += QLatin1Char(' ') + args.join(QLatin1Char(' '));
    }

    if (isFlatpakRuntime()) {
        fullCommandLine = QStringLiteral("flatpak-spawn --host -- %1").arg(fullCommandLine);
    }

    config.commandLine = fullCommandLine;
    config.desktopName = desktopName;
    config.valid = true;
    return config;
}
} // namespace

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

} // namespace TerminalLauncher
