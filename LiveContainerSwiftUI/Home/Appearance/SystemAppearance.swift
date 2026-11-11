//
//  SystemAppearance.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Whether iOS is in Dark Mode. The Home Screen keeps ryC0's window
/// dark whatever the setting, so the window's own appearance can't tell; the
/// scene's still follows the system, and this follows the scene.
@MainActor
@Observable
final class SystemAppearance {
    /// Whether Dark Mode is on.
    private(set) var isDark = UITraitCollection.current.userInterfaceStyle == .dark

    /// The scene whose appearance this follows. When it disconnects, which
    /// on iPad can happen while ryC0 is in the background, the main
    /// window's next scene takes over.
    @ObservationIgnored private weak var followedScene: UIWindowScene?
    @ObservationIgnored private var registration: (any UITraitChangeRegistration)?

    /// Follows the appearance of the scene ryC0's main window shows in,
    /// from now on, in place of the one it followed before. Calling it again
    /// for the same scene only reads the appearance afresh.
    func follow(_ scene: UIWindowScene) {
        update(from: scene)
        guard scene !== followedScene else {
            return
        }
        if let registration {
            followedScene?.unregisterForTraitChanges(registration)
        }
        followedScene = scene
        registration = scene.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (scene: UIWindowScene, _: UITraitCollection) in
            self?.update(from: scene)
        }
    }

    /// Reads whether a scene is in Dark Mode, changing `isDark` only when the
    /// answer is new, so the views reading it don't redraw for nothing.
    private func update(from scene: UIWindowScene) {
        let isDark = scene.traitCollection.userInterfaceStyle == .dark
        if isDark != self.isDark {
            self.isDark = isDark
        }
    }
}
