//
//  HomePresentedScreenView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The screen open over the Home Screen: ryC0's Settings, or an app's
/// settings. The Home button at the bottom goes back to the Home Screen from
/// any of its pages. Settings on an iPad wide enough for its sidebar shows
/// the button at the bottom of the sidebar instead.
struct HomePresentedScreenView: View {
    /// Which screen to show.
    let screen: HomePresentedScreen

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// This screen's whole size, measured on iPad only and handed down as
    /// `presentedScreenSize`. It stays nil on iPhone.
    @State private var size: CGSize?

    var body: some View {
        Group {
            switch screen {
            case .settings:
                SettingsView()
            case .appSettings(let app):
                HomeAppSettingsScreen(app: app)
            case .guest:
                EmptyView()
            }
        }
        .homeButtonBar(isShown: showsHomeButtonBar, action: model.goHome)
        .background {
            if !SharedModel.isPhone {
                Color.clear
                    .ignoresSafeArea()
                    .onGeometryChange(for: CGSize.self, of: { $0.size }, action: sizeChanged)
            }
        }
        .environment(\.presentedScreenSize, size)
    }

    /// Whether the Home button shows in a bar across the bottom, which it
    /// does except where Settings puts it in its sidebar.
    private var showsHomeButtonBar: Bool {
        guard case .settings = screen else {
            return true
        }
        return !SettingsSplitView.placesHomeButtonInSidebar(horizontalSizeClass)
    }

    private func sizeChanged(_ newSize: CGSize) {
        size = newSize
    }
}
