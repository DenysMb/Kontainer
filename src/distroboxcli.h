/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
*/

#pragma once

#include <QString>
#include <QStringList>

namespace DistroboxCli
{
struct AvailableImages {
    QStringList displayNames;
    QStringList fullNames;
};

QString runCommand(const QString &command, bool &success);
AvailableImages availableImages();
QString containersJson();
QString availableImagesJson(const AvailableImages &images);
bool isFlatpak();
}
