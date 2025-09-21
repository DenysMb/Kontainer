/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
*/

#pragma once

#include <QString>
#include <functional>

class QObject;

namespace TerminalLauncher
{
Q_REQUIRED_RESULT bool launch(const QString &command, const QString &workingDirectory, QObject *parent, const std::function<void(bool)> &onFinished = {});
}
