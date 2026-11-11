//
//  SettingsPageView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The page a row of Settings opens: pushed over the list on iPhone, and on
/// iPad shown in the detail column beside the sidebar.
struct SettingsPageView: View {
    /// Which page to show.
    let page: SettingsPage

    var body: some View {
        switch page {
        case .signing, .attention:
            SigningSettingsView()
        case .general:
            GeneralSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .wallpaper:
            WallpaperSettingsView()
        case .apps:
            AppsSettingsView()
        case .advanced:
            AdvancedSettingsView()
        }
    }
}
