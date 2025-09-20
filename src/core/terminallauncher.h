/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
*/

#pragma once

#include <QString>
#include <QStringList>
#include <QMap>

class QObject;

struct TerminalSpec {
    QString executable;          // the program to run
    QStringList argsTemplate;    // template args with $command/$workdir placeholders
};

namespace TerminalLauncher
{
Q_REQUIRED_RESULT bool launch(const QString &command, const QString &workingDirectory, QObject *parent);

// Terminal specifications map
extern const QMap<QString, TerminalSpec> terminalSpecs;
}

