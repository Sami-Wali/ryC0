//
//  HomeRouter+Certificates.swift
//  LiveContainerSwiftUI
//

import SwiftUI

extension HomeRouter {
    /// Asks whether to use the certificate a link sent, once ZSign opens it.
    func review(_ certificate: CertificateLink) async {
        guard acceptsCertificates() else {
            return
        }
        guard let teamID = await SigningCertificateImport.teamID(of: certificate.certificateData, password: certificate.password) else {
            launchProblem = "lc.settings.invalidCertError".loc
            return
        }
        askToUse(certificate, teamID: teamID, source: .link)
    }

    /// Reads a .p12 file ryC0 was asked to open, then asks for its
    /// password. A copy iOS left in the Inbox is deleted once read, so the
    /// private key doesn't stay behind there.
    func openCertificateFile(_ url: URL) {
        guard acceptsCertificates() else {
            return
        }
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: url)
            let inbox = URL.documentsDirectory.appendingPathComponent("Inbox")
            if url.deletingLastPathComponent().standardizedFileURL == inbox.standardizedFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            lockedCertificate = LockedCertificate(data: data, isRetry: false)
        } catch {
            launchProblem = "ryc0.certificateImport.unreadable".loc
        }
    }

    /// Opens a .p12 file with the password typed for it and asks whether to
    /// use it, or asks for the password again when it doesn't open.
    func unlock(_ locked: LockedCertificate, password: String) async {
        let certificate = CertificateLink(certificateData: locked.data, password: password)
        guard let teamID = await SigningCertificateImport.teamID(of: locked.data, password: password) else {
            lockedCertificate = LockedCertificate(data: locked.data, isRetry: true)
            return
        }
        askToUse(certificate, teamID: teamID, source: .file)
    }

    func use(_ offer: CertificateOffer) async {
        let certificate = offer.certificate
        SigningCertificateImport.store(certificate.certificateData, password: certificate.password)
        certificatesStored += 1
        guard !onboarding.isPresented else {
            return
        }
        let (passed, error) = await SigningCertificate.validateJITLessSetup()
        SigningCertificate.lastCheckPassed = passed
        guard passed else {
            var reason = "lc.jitlessSetup.error.testLibLoadFailed".loc
            if let error {
                reason += "\n" + error.localizedDescription.loc
            }
            launchProblem = reason
            return
        }
        storedCertificateTeam = offer.teamID
    }

    func decline(_ offer: CertificateOffer) {
        if certificateOffer == offer {
            certificateOffer = nil
        }
    }

    /// Whether this ryC0 takes certificates. A second ryC0 signs
    /// with the first one's certificate, so it says where to import instead.
    private func acceptsCertificates() -> Bool {
        guard sharedModel.multiLCStatus != 2 else {
            launchProblem = "ryc0.certificateImport.secondary".loc
            return false
        }
        return true
    }

    /// Asks whether to use a certificate ZSign opened, when it belongs to the
    /// team that signed ryC0, or to a team ryC0 can't tell. A
    /// question still open about another certificate is answered as declined,
    /// since only one shows at a time.
    func askToUse(_ certificate: CertificateLink, teamID: String, source: CertificateSource) {
        if let ownTeamID = LCSharedUtils.teamIdentifier(), ownTeamID != teamID {
            let problem = "ryc0.certificateImport.otherTeam %@ %@".localizeWithFormat(teamID, ownTeamID)
            launchProblem = problem
            return
        }
        if let openOffer = certificateOffer {
            decline(openOffer)
        }
        certificateOffer = CertificateOffer(
            certificate: certificate,
            teamID: teamID,
            replacesCurrent: LCSharedUtils.certificatePassword() != nil,
            source: source
        )
    }
}
