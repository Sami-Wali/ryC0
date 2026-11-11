//
//  HomePresentedScreen.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A screen that opens over the Home Screen the way an app opens: zooming out
/// of the icon it belongs to.
enum HomePresentedScreen: Identifiable {
    /// ryC0's Settings.
    case settings
    /// One app's settings.
    case appSettings(LCAppModel)
    /// A full-screen app hosted by LiveProcess.
    case guest(sourceID: String)

    var id: String {
        if case .guest(let sourceID) = self { return "guest:\(sourceID)" }
        return zoomSourceID
    }

    /// The icon the screen zooms out of: Settings, or the app's icon.
    var zoomSourceID: String {
        switch self {
        case .settings:
            HomeItem.settings.id
        case .appSettings(let app):
            app.homeKey.map { HomeItem.app($0).id } ?? "appSettings"
        case .guest(let sourceID):
            sourceID
        }
    }
}
