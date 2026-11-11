//
//  SigningNoticeSection.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct SigningNoticeSection: View {
    /// What is wrong.
    let attention: SigningAttention

    @Environment(SigningStatus.self) private var connection

    var body: some View {
        Section {
            Label {
                Text(message)
            } icon: {
                Image(systemName: attention == .notSetUp ? "info.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(attention == .notSetUp ? Color.secondary : Color.red)
            }

            SigningImportCertificateButton(title: "lc.settings.importCertificate".loc)
        }
    }

    /// The problem the setup check recorded, when there
    /// is one, or what the attention means.
    private var message: String {
        if let problem = connection.problem {
            return problem
        }
        return switch attention {
        case .notSetUp:
            "ryc0.settings.signing.description".loc
        case .problem:
            "ryc0.settings.signing.signingFailedNotice".loc
        case .expired:
            "ryc0.settings.signing.expiredNotice".loc
        case .revoked:
            "ryc0.settings.signing.revokedNotice".loc
        }
    }
}
