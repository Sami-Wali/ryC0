//
//  SigningCertificateFooter.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct SigningCertificateFooter: View {
    @Environment(SigningStatus.self) private var connection

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsDesign.headerSpacing) {
            Text(note)

            if case .unavailable(let reason) = connection.validity {
                Text("ryc0.settings.signing.couldNotCheckReason %@".localizeWithFormat(reason))
            }
        }
    }

    private var note: String {
        switch connection.source {
        case .imported:
            "ryc0.settings.signing.footerImported".loc
        case .none:
            "ryc0.settings.signing.description".loc
        }
    }
}
