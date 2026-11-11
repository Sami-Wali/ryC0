//
//  SigningCertificateSection.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct SigningCertificateSection: View {
    @Environment(SigningStatus.self) private var connection

    var body: some View {
        Section {
            LabeledContent("ryc0.settings.signing.status".loc) {
                SigningValidityLabel(validity: connection.validity)
            }

            if let teamID = connection.teamID {
                LabeledContent("lc.jitlessDiag.teamId".loc, value: teamID)
            }

            if let expiresAt = connection.expiresAt {
                LabeledContent("ryc0.settings.signing.expires".loc) {
                    Text(expiresAt, format: .dateTime.day().month().year())
                        .foregroundStyle(connection.isExpired ? Color.red : Color.secondary)
                }
            }
        } header: {
            Text("ryc0.settings.signing.certificate".loc)
        } footer: {
            SigningCertificateFooter()
        }
    }
}
