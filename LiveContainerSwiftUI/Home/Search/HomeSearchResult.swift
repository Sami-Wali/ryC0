//
//  HomeSearchResult.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One app in search: its icon and name, which open it, with its menu on a
/// long press.
struct HomeSearchResult: View {
    @ObservedObject var app: LCAppModel
    /// Where things go on this screen, for the icon's size.
    let metrics: HomeMetrics
    /// Whether the icon shows in its dark version, as the icon style asks.
    let darkModeIcon: Bool

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        Button(action: open) {
            HomeIconContent(item: item, app: app, metrics: metrics, showsLabel: true, darkModeIcon: darkModeIcon)
        }
        .buttonStyle(HomeIconButtonStyle())
        .accessibilityLabel(app.displayName)
        .contentShape(.contextMenuPreview, HomeIconPreviewShape(iconSize: metrics.iconSize, cornerRadius: metrics.iconCornerRadius))
        .contextMenu {
            HomeAppMenu(app: app, showsEditHomeScreen: false)
        }
    }

    private var item: HomeItem {
        .app(app.homeKey ?? "")
    }

    private func open() {
        model.openSearchResult(app)
    }
}
