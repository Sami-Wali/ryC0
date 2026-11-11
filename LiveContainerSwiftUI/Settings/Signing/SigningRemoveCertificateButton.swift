//
//  SigningRemoveCertificateButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Removes the stored certificate, after asking, so ryC0 stops signing
/// apps until it has one again.
struct SigningRemoveCertificateButton: View {
    @Environment(SigningStatus.self) private var connection
    @State private var isConfirming = false

    var body: some View {
        Button("lc.settings.removeCertificate".loc, role: .destructive, action: confirm)
            .confirmationDialog("ryc0.settings.signing.removeTitle".loc, isPresented: $isConfirming, titleVisibility: .visible) {
                Button("lc.common.remove".loc, role: .destructive, action: remove)
            } message: {
                Text("ryc0.settings.signing.removeMessage".loc)
            }
    }

    private func confirm() {
        isConfirming = true
    }

    private func remove() {
        connection.removeCertificate()
    }
}
