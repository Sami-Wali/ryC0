//
//  EnvironmentValues+PresentedScreenSize.swift
//  LiveContainerSwiftUI
//

import SwiftUI

extension EnvironmentValues {
    /// On iPad, the whole size of the screen open over the Home Screen, such
    /// as Settings, which is the window's size. The wallpaper preview takes
    /// its shape from it, as the Home Screen under a full screen cover may
    /// stop laying out and so stop reporting its own size. HomePresentedScreenView
    /// sets it; it stays nil on iPhone.
    @Entry var presentedScreenSize: CGSize? = nil
}
