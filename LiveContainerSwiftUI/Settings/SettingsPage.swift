//
//  SettingsPage.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A page of Settings, which a row of its list opens. On iPad the list is
/// Settings' sidebar, and the page picked there shows beside it, as in the
/// iPad's Settings app.
enum SettingsPage: Hashable {
    case signing
    case attention
    /// Settings > General.
    case general
    /// Settings > Appearance.
    case appearance
    /// Settings > Wallpaper.
    case wallpaper
    /// Settings > Apps, which holds each app's settings.
    case apps
    /// Settings > Advanced.
    case advanced

    var shownPage: SettingsPage {
        self == .attention ? .signing : self
    }
}
