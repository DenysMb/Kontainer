/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
*/

#pragma once

#include <QString>
#include <optional>

namespace PackageInstallCommand
{
std::optional<QString> forImage(const QString &image, const QString &packagePath);
}
