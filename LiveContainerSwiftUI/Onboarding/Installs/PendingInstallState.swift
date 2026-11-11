//
//  PendingInstallState.swift
//  LiveContainerSwiftUI
//

/// How far an app in PendingInstallQueue has come.
enum PendingInstallState: Equatable, Codable {
    case downloading

    /// Its IPA is on this iPhone, waiting for its turn, or for onboarding to
    /// reach Add Apps.
    case waiting

    /// It's being unpacked, moved in and signed.
    case installing

    /// It's on the Home Screen.
    case installed

    /// Nothing was added: the person kept the copy already installed, or
    /// the install stopped and said why in an alert.
    case notInstalled

    /// It couldn't be downloaded or installed, for this reason.
    case failed(String)

    /// Whether it's done coming in, one way or another.
    var isFinished: Bool {
        switch self {
        case .downloading, .waiting, .installing:
            false
        case .installed, .notInstalled, .failed:
            true
        }
    }
}
