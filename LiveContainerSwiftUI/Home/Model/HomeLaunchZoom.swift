//
//  HomeLaunchZoom.swift
//  LiveContainerSwiftUI
//

import Foundation

/// An app zooming open from its icon, just before ryC0 turns into it.
struct HomeLaunchZoom: Identifiable, Equatable {
    /// The icon the app opens from.
    let item: HomeItem
    /// The app opening.
    let app: LCAppModel
    /// The icon's frame on screen, where the zoom starts.
    let iconFrame: CGRect
    /// Tells this zoom from an earlier one of the same app.
    let id = UUID()
}
