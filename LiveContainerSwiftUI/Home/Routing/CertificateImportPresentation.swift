//
//  CertificateImportPresentation.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Shows the questions a certificate sent to ryC0 asks, over the main
/// window's root: the password of a .p12 file opened with ryC0, whether
/// ryC0 should sign apps with the certificate, and that it's ready once
/// stored and checked. HomeRouter decides which one shows.
struct CertificateImportPresentation: ViewModifier {
    let router: HomeRouter

    /// The password typed for a .p12 file.
    @State private var password = ""

    func body(content: Content) -> some View {
        @Bindable var router = router

        content
            .alert(
                "ryc0.settings.signing.passwordTitle".loc,
                isPresented: Binding<Bool>.isPresented(for: $router.lockedCertificate),
                presenting: router.lockedCertificate
            ) { locked in
                SecureField("ryc0.settings.signing.password".loc, text: $password)
                Button("lc.common.continue".loc) {
                    unlock(locked)
                }
                Button("lc.common.cancel".loc, role: .cancel, action: forgetPassword)
            } message: { locked in
                Text(locked.isRetry ? "ryc0.certificateImport.wrongPassword".loc : "ryc0.settings.signing.passwordMessage".loc)
            }
            .alert(
                "ryc0.certificateImport.title".loc,
                isPresented: Binding<Bool>.isPresented(for: $router.certificateOffer),
                presenting: router.certificateOffer
            ) { offer in
                Button("ryc0.certificateImport.use".loc) {
                    use(offer)
                }
                Button("lc.common.cancel".loc, role: .cancel) {
                    decline(offer)
                }
            } message: { offer in
                Text(message(for: offer))
            }
            .alert(
                "ryc0.certificateImport.readyTitle".loc,
                isPresented: Binding<Bool>.isPresented(for: $router.storedCertificateTeam),
                presenting: router.storedCertificateTeam
            ) { _ in
                Button("lc.common.ok".loc) { }
            } message: { teamID in
                Text("ryc0.certificateImport.readyMessage %@".localizeWithFormat(teamID))
            }
    }

    /// What the question says: the certificate's team, and that it takes the
    /// place of the certificate ryC0 has, when it has one.
    private func message(for offer: CertificateOffer) -> String {
        let key = offer.replacesCurrent ? "ryc0.certificateImport.replaceMessage %@" : "ryc0.certificateImport.message %@"
        return key.localizeWithFormat(offer.teamID)
    }

    private func unlock(_ locked: LockedCertificate) {
        let password = password
        forgetPassword()
        Task {
            await router.unlock(locked, password: password)
        }
    }

    private func use(_ offer: CertificateOffer) {
        Task {
            await router.use(offer)
        }
    }

    private func decline(_ offer: CertificateOffer) {
        router.decline(offer)
    }

    private func forgetPassword() {
        password = ""
    }
}

extension View {
    /// Shows the questions a certificate sent to ryC0 asks. Apply it
    /// once, on the main window's root.
    func certificateImportPresentation(_ router: HomeRouter) -> some View {
        modifier(CertificateImportPresentation(router: router))
    }
}
