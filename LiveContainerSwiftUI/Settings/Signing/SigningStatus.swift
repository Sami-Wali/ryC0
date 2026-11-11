//
//  SigningStatus.swift
//  LiveContainerSwiftUI
//

import SwiftUI

@MainActor
@Observable
final class SigningStatus {
    /// Where the stored certificate came from, or `.none`.
    private(set) var source: SigningCertificateSource = .none
    private(set) var teamID: String?
    private(set) var expiresAt: Date?
    var problem: String? { result(for: .signing).failure }
    /// Whether this is a second ryC0, which signs with the first one's
    /// certificate and has none of its own to manage.
    private(set) var isSecondary = false
    /// What Apple said about the certificate when last asked.
    private(set) var validity: SigningCertificateValidity = .unknown
    /// Whether Check Setup is running.
    private(set) var isCheckingSetup = false
    /// Goes up by one whenever a different certificate is stored or none is,
    /// so pages can ask Apple about the new one.
    private(set) var certificateVersion = 0
    /// The team that signed ryC0, which the certificate has to belong
    /// to, or nil when ryC0's entitlements don't say.
    private(set) var ownTeamID: String?

    /// How Check Setup found each part, for the parts it looked at.
    private var results: [SigningSetupCheck: SigningCheckResult] = [:]
    @ObservationIgnored private var teamTask: Task<Void, Never>?

    private var defaults: UserDefaults {
        LCUtils.appGroupUserDefault
    }

    /// Reads what is stored, which takes no time. Reading an imported
    /// certificate's team waits for `reload()`, which the pages call when
    /// they appear.
    init() {
        readStoredState()
    }

    /// Whether a certificate is stored, so ryC0 can sign apps.
    var hasCertificate: Bool {
        source != .none
    }

    /// Whether the certificate's expiry date has passed.
    var isExpired: Bool {
        expiresAt.map { $0 < .now } ?? false
    }

    /// Why ryC0 can't sign apps right now, or nil when nothing is known
    /// to be wrong.
    var attention: SigningAttention? {
        guard !isSecondary else {
            return nil
        }
        if !hasCertificate {
            return .notSetUp
        }
        if problem != nil || result(for: .signing).failure != nil {
            return .problem
        }
        if isExpired {
            return .expired
        }
        if validity == .revoked {
            return .revoked
        }
        return nil
    }

    /// One line on the certificate for the card at the top of Settings: its
    /// team and when it expires, as far as they are known.
    var summary: String {
        if isSecondary {
            return "lc.settings.multiLCIsSecond".loc
        }
        var parts: [String] = []
        switch source {
        case .none:
            return "ryc0.settings.signing.noCertificate".loc
        case .imported:
            parts.append("ryc0.settings.signing.importedCertificate".loc)
        }
        if let teamID {
            parts.append("ryc0.signingCertificate.team %@".localizeWithFormat(teamID))
        }
        if let expiresAt {
            let date = expiresAt.formatted(date: .abbreviated, time: .omitted)
            let key = isExpired ? "ryc0.signingCertificate.expired %@" : "ryc0.signingCertificate.expires %@"
            parts.append(key.localizeWithFormat(date))
        }
        return parts.joined(separator: " · ")
    }

    /// How Check Setup found one part.
    func result(for check: SigningSetupCheck) -> SigningCheckResult {
        results[check] ?? .notChecked
    }

    func reload() {
        readStoredState()
        if source == .imported && teamID == nil {
            readImportedTeam()
        }
    }

    private func readStoredState() {
        isSecondary = DataManager.shared.model.multiLCStatus == 2
        ownTeamID = LCSharedUtils.teamIdentifier()
        source = LCSharedUtils.certificatePassword() == nil ? .none : .imported
        if source == .none {
            teamID = nil
            expiresAt = nil
        }

        results[.sharedStorage] = SigningEntitlements.hasSharedStorage ? .passed : .missing
        results[.separateLogins] = SigningEntitlements.hasLoginGroups ? .passed : .missing
    }

    /// Asks Apple whether the certificate is still good, as the JIT-less
    /// diagnosis does, which also tells when it expires. It asks again only
    /// when there's no answer yet for this certificate.
    func checkCertificateIfNeeded() async {
        switch validity {
        case .unknown, .unavailable:
            break
        case .checking, .valid, .revoked:
            return
        }
        guard hasCertificate else {
            return
        }
        let version = certificateVersion
        validity = .checking
        let answer = await Self.askApple()
        guard version == certificateVersion else {
            return
        }
        if let date = answer.expiresAt {
            expiresAt = date
        }
        if let team = answer.teamID, !team.isEmpty {
            teamID = team
        }
        switch answer.status {
        case 0:
            validity = .valid
        case 1:
            validity = .revoked
        default:
            validity = .unavailable(answer.error?.loc ?? "lc.common.unknown".loc)
        }
    }

    /// Check Setup: looks at the app group and the keychain groups again, then
    /// signs a test library with the certificate, the way apps are signed, and
    /// checks that iOS accepts it, as it has to for apps to open without JIT.
    /// When that works, a failed check recorded at launch no longer stands.
    ///
    /// When a different certificate is stored before the check is done, what
    /// it found is dropped and it checks again, for the new certificate. A
    /// page that asks for a check meanwhile gets that one.
    func checkSetup() async {
        guard !isCheckingSetup else {
            return
        }
        isCheckingSetup = true
        defer {
            isCheckingSetup = false
        }
        var checkedVersion: Int
        repeat {
            checkedVersion = certificateVersion
            await checkSetupOnce()
        } while checkedVersion != certificateVersion
    }

    /// One run of Check Setup, for the certificate stored as it starts. It
    /// keeps nothing it found about signing once a different certificate is
    /// stored before it's done, since `checkSetup()` then runs again.
    private func checkSetupOnce() async {
        reload()

        guard hasCertificate else {
            results[.signing] = .failed("ryc0.settings.setup.noCertificate".loc)
            SigningCertificate.lastCheckPassed = false
            return
        }
        let version = certificateVersion
        results[.signing] = .checking
        let (passed, error) = await SigningCertificate.validateJITLessSetup()
        guard version == certificateVersion else {
            return
        }
        SigningCertificate.lastCheckPassed = passed
        if passed {
            results[.signing] = .passed
        } else {
            var reason = "lc.jitlessSetup.error.testLibLoadFailed".loc
            if let error {
                reason += "\n" + error.localizedDescription.loc
            }
            results[.signing] = .failed(reason)
        }
    }

    /// Stores a .p12 of the person's own in place of the current certificate,
    /// once ZSign opens it with the password, as long as it belongs to the
    /// team that signed ryC0 (or ryC0 can't tell that team), the
    /// way a certificate link is checked. Throws the error to show when it
    /// doesn't open or belongs to another team.
    func importCertificate(_ data: Data, password: String) async throws {
        guard let team = await SigningCertificateImport.teamID(of: data, password: password) else {
            throw "lc.settings.invalidCertError".loc
        }
        // Apps signed with another team's certificate wouldn't open.
        if let ownTeam = LCSharedUtils.teamIdentifier(), ownTeam != team {
            throw "ryc0.certificateImport.otherTeam %@ %@".localizeWithFormat(team, ownTeam)
        }
        SigningCertificateImport.store(data, password: password)
        certificateChanged()
    }

    /// Forgets the certificate, so ryC0 can't sign apps until it has
    /// one again.
    func removeCertificate() {
        defaults.removeObject(forKey: SigningCertificateImport.certificateDataKey)
        defaults.removeObject(forKey: SigningCertificateImport.certificatePasswordKey)
        defaults.removeObject(forKey: SigningCertificateImport.certificateDateKey)
        SigningCertificate.lastCheckPassed = false
        UserDefaults.standard.removeObject(forKey: SigningCertificateImport.appGroupKey)
        certificateChanged()
    }

    func certificateChanged() {
        teamTask?.cancel()
        validity = .unknown
        results[.signing] = nil
        teamID = nil
        expiresAt = nil
        certificateVersion += 1
        reload()
    }

    /// Reads which team an imported certificate belongs to, which takes ZSign
    /// opening it, away from the main thread.
    private func readImportedTeam() {
        guard let data = LCUtils.certificateData(),
              let password = LCSharedUtils.certificatePassword() else {
            return
        }
        let version = certificateVersion
        teamTask?.cancel()
        teamTask = Task { [weak self] in
            let team = await Task.detached(priority: .utility) {
                LCUtils.getCertTeamId(withKeyData: data, password: password)
            }.value
            guard let self, !Task.isCancelled, version == self.certificateVersion else {
                return
            }
            self.teamID = team
        }
    }

    /// Asks Apple about the stored certificate over OCSP, through ZSign.
    /// Status 0 means good and 1 revoked; anything else comes with the error.
    private static func askApple() async -> (status: Int32, expiresAt: Date?, teamID: String?, error: String?) {
        await withCheckedContinuation { continuation in
            _ = LCUtils.validateCertificate { status, expiresAt, teamID, error in
                continuation.resume(returning: (status, expiresAt, teamID, error))
            }
        }
    }
}
