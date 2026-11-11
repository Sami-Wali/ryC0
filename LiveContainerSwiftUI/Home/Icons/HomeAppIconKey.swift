//
//  HomeAppIconKey.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Which icon HomeAppIconImage shows: an app's, in its light or dark version.
/// The view has the icon drawn whenever this changes, such as when an update
/// takes the app's place or the icon style turns dark.
struct HomeAppIconKey: Equatable {
    /// The app.
    let app: LCAppModel
    /// Whether the icon is the dark version.
    let isDark: Bool
    /// The app's icon generation, which Clear Icon Cache moves on.
    let generation: Int
}
