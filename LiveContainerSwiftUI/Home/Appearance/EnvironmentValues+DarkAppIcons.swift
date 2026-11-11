//
//  EnvironmentValues+DarkAppIcons.swift
//  LiveContainerSwiftUI
//

import SwiftUI

extension EnvironmentValues {
    /// Whether apps' icons show in their dark versions, from the icon style
    /// chosen in Settings and whether Dark Mode is on. AppIconAppearance sets
    /// it for the whole window.
    @Entry var prefersDarkAppIcons = false
}
