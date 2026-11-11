//
//  SigningImportCertificateButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UniformTypeIdentifiers

/// Imports a certificate of the person's own: picks a .p12 in Files, asks for
/// its password, and stores it once ZSign opens it with that password. The
/// certificate has to belong to the team that signed ryC0 for the apps
/// it signs to open.
struct SigningImportCertificateButton: View {
    /// The button's text, already localized.
    let title: String

    @Environment(SigningStatus.self) private var connection

    @State private var isPickingFile = false
    /// The .p12 picked in Files, while its password is asked for.
    @State private var pickedCertificate: Data?
    @State private var password = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        Button(title, action: pickFile)
            .disabled(isImporting)
            .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.p12], onCompletion: filePicked)
            .alert(
                "ryc0.settings.signing.passwordTitle".loc,
                isPresented: Binding<Bool>.isPresented(for: $pickedCertificate),
                presenting: pickedCertificate
            ) { certificate in
                SecureField("ryc0.settings.signing.password".loc, text: $password)
                Button("ryc0.settings.signing.import".loc) {
                    importCertificate(certificate)
                }
                Button("lc.common.cancel".loc, role: .cancel, action: forgetPassword)
            } message: { _ in
                Text("ryc0.settings.signing.passwordMessage".loc)
            }
            .alert(
                "lc.common.error".loc,
                isPresented: Binding<Bool>.isPresented(for: $errorMessage),
                presenting: errorMessage
            ) { _ in
                Button("lc.common.ok".loc) { }
            } message: { message in
                Text(message)
            }
    }

    private func pickFile() {
        isPickingFile = true
    }

    /// Reads the .p12 picked in Files, then asks for its password.
    private func filePicked(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            password = ""
            pickedCertificate = try Data(contentsOf: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importCertificate(_ certificate: Data) {
        let password = password
        forgetPassword()
        isImporting = true
        Task {
            defer {
                isImporting = false
            }
            do {
                try await connection.importCertificate(certificate, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func forgetPassword() {
        password = ""
    }
}
