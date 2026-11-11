//
//  AppInstallOutcome.swift
//  LiveContainerSwiftUI
//

/// How an install ended.
enum AppInstallOutcome {
    /// The app was installed as a new app.
    case added(LCAppModel)
    /// The app took the place of an installed copy, with that copy's data and
    /// settings.
    case replaced(LCAppModel)
    /// Nothing changed: the person kept what was installed, or didn't pass
    /// Face ID.
    case cancelled

    /// The app the install added or replaced, or nil when it was cancelled.
    var app: LCAppModel? {
        switch self {
        case .added(let app), .replaced(let app):
            app
        case .cancelled:
            nil
        }
    }
}
