//
//  SigningValidityLabel.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What Apple said about the certificate, on the trailing side of its Status
/// row: a spinner while asking, then Valid, Revoked, or that it couldn't be
/// asked. Each answer has its own symbol as well as its color. The symbol
/// and the word sit in a plain stack, since a Label there would line the
/// row's separator up with the word.
struct SigningValidityLabel: View {
    let validity: SigningCertificateValidity

    var body: some View {
        switch validity {
        case .unknown:
            Text("ryc0.settings.setup.notChecked".loc)
                .foregroundStyle(.secondary)
        case .checking:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("lc.jitlessDiag.checking".loc)
        case .valid:
            answer("lc.jitlessDiag.certificateValid".loc, systemImage: "checkmark.seal.fill", color: .green)
        case .revoked:
            answer("lc.jitlessDiag.certificateRevoked".loc, systemImage: "xmark.seal.fill", color: .red)
        case .unavailable:
            answer("ryc0.settings.signing.couldNotCheck".loc, systemImage: "questionmark.circle", color: .secondary)
        }
    }

    private func answer(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(title)
        }
        .foregroundStyle(color)
    }
}
