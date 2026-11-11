//
//  SigningCertificateImport.swift
//  LiveContainerSwiftUI
//

import Foundation

enum SigningCertificateImport {
    // The keys in the shared defaults, which the guest signer reads.
    static let certificateDataKey = "LCCertificateData"
    static let certificatePasswordKey = "LCCertificatePassword"
    static let certificateDateKey = "LCCertificateUpdateDate"
    static let appGroupKey = "LCAppGroupID"

    /// The team a .p12 belongs to, once ZSign opens it with the password, or
    /// nil when it doesn't open.
    static func teamID(of data: Data, password: String) async -> String? {
        // ZSign opens the .p12 on the calling thread, so it runs away from
        // the main one.
        await Task.detached(priority: .userInitiated) {
            LCUtils.getCertTeamId(withKeyData: data, password: password)
        }.value
    }

    @MainActor
    static func store(_ data: Data, password: String) {
        let defaults = LCUtils.appGroupUserDefault
        defaults.set(data, forKey: certificateDataKey)
        defaults.set(password, forKey: certificatePasswordKey)
        defaults.set(Date.now, forKey: certificateDateKey)
        SigningCertificate.lastCheckPassed = nil
        rememberAppGroup()
    }

    /// Remembers the app group the certificate came with, or forgets the one
    /// remembered when ryC0 has none, so the placeholder name
    /// LCSharedUtils gives then is never kept as if it were a group.
    private static func rememberAppGroup() {
        if LCSharedUtils.hasAppGroup() {
            UserDefaults.standard.set(LCSharedUtils.appGroupID(), forKey: appGroupKey)
        } else {
            UserDefaults.standard.removeObject(forKey: appGroupKey)
        }
    }
}
