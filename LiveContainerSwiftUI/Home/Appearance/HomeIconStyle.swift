//
//  HomeIconStyle.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Which versions of apps' icons ryC0 shows, chosen in Settings > Home
/// Screen: the dark ones while Dark Mode is on, as iOS does by default, or
/// always the light or the dark ones.
enum HomeIconStyle: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    /// The defaults key the choice is saved under, in the app group's defaults.
    static let storageKey = "RYC0HomeIconStyle"

    var id: Self {
        self
    }

    /// The choice's name in Settings.
    var title: String {
        switch self {
        case .automatic:
            "ryc0.settings.appearance.iconStyle.automatic".loc
        case .light:
            "ryc0.settings.appearance.iconStyle.light".loc
        case .dark:
            "ryc0.settings.appearance.iconStyle.dark".loc
        }
    }

    /// Whether icons show in their dark versions, given whether Dark Mode is on.
    func prefersDarkIcons(systemIsDark: Bool) -> Bool {
        switch self {
        case .automatic:
            systemIsDark
        case .light:
            false
        case .dark:
            true
        }
    }
}
