//
//  AppShortcutRequest.swift
//  LiveContainerSwiftUI
//

import Foundation

/// An app asked to go on the iPhone's own Home Screen, waiting for Add to Home
/// Screen's sheet, with its icon in the style ryC0's Home Screen shows
/// it in.
struct AppShortcutRequest: Identifiable, Equatable {
    let id = UUID()
    /// The app the web clip opens.
    let app: LCAppModel
    /// The icon's style: dark when ryC0's Home Screen shows dark icons.
    let style: GeneratedIconStyle

    static func == (lhs: AppShortcutRequest, rhs: AppShortcutRequest) -> Bool {
        lhs.id == rhs.id
    }
}
