import SwiftUI

/// Import, replace, or remove the certificate used to sign guest apps.
struct SigningCertificateActions: View {
    @Environment(SigningStatus.self) private var connection

    var body: some View {
        Section {
            SigningImportCertificateButton(title: connection.hasCertificate
                ? "lc.settings.importOtherCertificate".loc
                : "lc.settings.importCertificate".loc)
            if connection.hasCertificate {
                SigningRemoveCertificateButton()
            }
        } footer: {
            Text(connection.hasCertificate
                ? "ryc0.settings.signing.actionsFooterImported".loc
                : "ryc0.settings.signing.actionsFooterNone".loc)
        }
    }
}
