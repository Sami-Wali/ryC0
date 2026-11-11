//
//  AppUpdateConfirmationKind.swift
//  LiveContainerSwiftUI
//

/// What replacing an installed app with another copy of it does to its
/// version, which decides how the question before it is worded.
enum AppUpdateConfirmationKind: Equatable, Sendable {
    /// The new copy is a newer version.
    case update
    /// The new copy is an older version, which the app may not be able to
    /// read the data of.
    case downgrade
    /// The new copy is the version installed already.
    case reinstall
}
