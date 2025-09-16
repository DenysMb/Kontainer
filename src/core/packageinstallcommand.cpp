/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
*/

#include "packageinstallcommand.h"

#include <KShell>
#include <QRegularExpression>

using namespace Qt::Literals::StringLiterals;

namespace PackageInstallCommand
{
std::optional<QString> forImage(const QString &image, const QString &packagePath)
{
    const QString imageLower = image.toLower();

    if (imageLower.contains(QRegularExpression(u"fedora|bluefin|ublue-os/fedora|fedoraproject\\.org/fedora"_s))) {
        return u"sudo dnf install %1"_s.arg(packagePath);
    }
    if (imageLower.contains(QRegularExpression(u"ubuntu|toolbx/ubuntu|ubuntu-toolbox|debian|neurodebian|mint|kali|neon"_s))) {
        return u"sudo apt install %1"_s.arg(packagePath);
    }
    if (imageLower.contains(QRegularExpression(u"opensuse|tumbleweed|leap"_s))) {
        return u"sudo zypper install %1"_s.arg(packagePath);
    }
    if (imageLower.contains(QRegularExpression(u"arch|blackarch|ublue-os/arch|bazzite-arch|arch-toolbox"_s))) {
        return u"sudo pacman -U --noconfirm %1"_s.arg(packagePath);
    }
    if (imageLower.contains(QRegularExpression(u"centos|rhel|rocky|alma|ubi[789]?/|amazonlinux|oracle"_s))) {
        return u"sudo dnf install %1"_s.arg(packagePath);
    }
    if (imageLower.contains(QRegularExpression(u"alpine"_s))) {
        return u"sudo apk add --allow-untrusted %1"_s.arg(packagePath);
    }
    if (imageLower.contains(QRegularExpression(u"void"_s))) {
        return u"sudo xbps-install %1"_s.arg(packagePath);
    }
    if (imageLower.contains(QRegularExpression(u"gentoo"_s))) {
        return u"sudo emerge %1"_s.arg(packagePath);
    }
    if (imageLower.contains(QRegularExpression(u"slack"_s))) {
        return u"sudo installpkg %1"_s.arg(packagePath);
    }
    if (imageLower.contains(QRegularExpression(u"wolfi|chainguard"_s))) {
        return u"sudo apk add --allow-untrusted %1"_s.arg(packagePath);
    }

    return std::nullopt;
}
}
