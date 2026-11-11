//
//  PendingInstallRecord.swift
//  LiveContainerSwiftUI
//

import Foundation

/// One app PendingInstallQueue is bringing in, as PendingInstallStore
/// writes it down, so the app comes back when ryC0 closes before it's
/// installed. Paths are kept relative to the app's folder, since iOS may
/// move ryC0's data to another path when it's updated.
struct PendingInstallRecord: Codable {
    /// The app's id, which also names its folder.
    var id: UUID
    /// Where it came from.
    var kind: PendingInstallKind
    /// What it's called until it's installed.
    var name: String
    /// How far it had come: downloading, waiting or installing.
    var state: PendingInstallState
    /// The install link's web address, for an app from a link.
    var address: String?
    /// The IPA's name in the app's folder, once it's there.
    var fileName: String?
    /// The bookmark that finds an opened IPA again.
    var bookmark: Data?
}
