//
//  AppInstallPolicy.swift
//  LiveContainerSwiftUI
//

/// What an install does when the app is installed already.
enum AppInstallPolicy: Equatable, Sendable {
    /// Asks whether the app replaces one of the installed copies or installs
    /// as a new app, as installs from links, files and Files do.
    case ask

    /// Installs the packaged ryP0 once, leaving existing copies in place.
    case bundledStore

}
