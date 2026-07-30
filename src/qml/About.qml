/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
    SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
*/

import org.kde.kirigamiaddons.formcard as FormCard
import org.kde.coreaddons

FormCard.AboutPage {
    aboutData: AboutData

    FormCard.FormHeader {
        title: i18n("Backend")
    }

    FormCard.FormCard {
        FormCard.FormTextDelegate {
            text: i18n("Distrobox version")
            description: distroBoxManager.distroboxVersion() || i18n("Not available")
        }

        FormCard.FormTextDelegate {
            text: i18n("Distrobox path")
            description: distroBoxManager.distroboxPath() || i18n("Not available")
        }
    }
}
