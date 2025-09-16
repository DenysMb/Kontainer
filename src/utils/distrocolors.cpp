/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
*/

#include "distrocolors.h"

#include <QRandomGenerator>
#include <QRegularExpression>
#include <QVector>

using namespace Qt::Literals::StringLiterals;

namespace DistroColors
{
QString colorForImage(const QString &image)
{
    const QString imageLower = image.toLower();

    struct DistroColor {
        QRegularExpression regex;
        QString color;
    };

    const QVector<DistroColor> distroColors = {// Major distributions
                                               {QRegularExpression(u"fedora|bluefin|ublue-os/fedora|fedoraproject\\.org/fedora"_s), u"#3c6eb4"_s},
                                               {QRegularExpression(u"ubuntu|toolbx/ubuntu|ubuntu-toolbox"_s), u"#e95420"_s},
                                               {QRegularExpression(u"debian|neurodebian"_s), u"#d70a53"_s},
                                               {QRegularExpression(u"opensuse|tumbleweed|leap"_s), u"#73ba25"_s},
                                               {QRegularExpression(u"arch|blackarch|ublue-os/arch|bazzite-arch|arch-toolbox"_s), u"#1793d1"_s},
                                               {QRegularExpression(u"centos|rhel|rocky|alma|ubi[789]?/|amazonlinux"_s), u"#262577"_s},
                                               // Other distributions
                                               {QRegularExpression(u"gentoo"_s), u"#54487a"_s},
                                               {QRegularExpression(u"alpine"_s), u"#0d597f"_s},
                                               {QRegularExpression(u"kali"_s), u"#367bf0"_s},
                                               {QRegularExpression(u"mint"_s), u"#87cf3e"_s},
                                               {QRegularExpression(u"void"_s), u"#478061"_s},
                                               {QRegularExpression(u"nixos"_s), u"#5277c3"_s},
                                               {QRegularExpression(u"deepin|linuxdeepin"_s), u"#0188D7"_s},
                                               {QRegularExpression(u"crystal"_s), u"#1E63A4"_s},
                                               {QRegularExpression(u"clear"_s), u"#003366"_s},
                                               {QRegularExpression(u"slack"_s), u"#333333"_s},
                                               {QRegularExpression(u"steamos"_s), u"#1A9FFF"_s},
                                               {QRegularExpression(u"vanilla"_s), u"#0F0F0F"_s},
                                               {QRegularExpression(u"wolfi|chainguard"_s), u"#007D9C"_s},
                                               {QRegularExpression(u"oracle"_s), u"#C74634"_s},
                                               {QRegularExpression(u"kde|neon"_s), u"#1D99F3"_s}};

    for (const auto &distro : distroColors) {
        if (imageLower.contains(distro.regex)) {
            return distro.color;
        }
    }

    auto *rng = QRandomGenerator::global();
    const int r = rng->bounded(100, 201);
    const int g = rng->bounded(100, 201);
    const int b = rng->bounded(100, 201);
    return u"#%1%2%3"_s.arg(r, 2, 16, QLatin1Char('0')).arg(g, 2, 16, QLatin1Char('0')).arg(b, 2, 16, QLatin1Char('0'));
}
}
