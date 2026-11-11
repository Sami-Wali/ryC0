//
//  HomeAppGrid.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Apps in rows of four with their names, as search shows them. A tap opens
/// an app and a long press opens its menu, without Edit Home Screen. On iPad
/// a wide panel holds five or six in a row instead, so they don't spread far
/// apart.
struct HomeAppGrid: View {
    /// The apps to show.
    let apps: [LCAppModel]
    /// Where things go on this screen, for the icons' size.
    let metrics: HomeMetrics

    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: columnCount), spacing: HomeDesign.searchSpacing) {
            ForEach(apps, id: \.self) { app in
                HomeSearchResult(app: app, metrics: metrics, darkModeIcon: darkModeIcon)
            }
        }
    }

    /// How many apps a row holds: four on iPhone, as always. On iPad, as many
    /// as fit the panel with at least the room each has on an iPhone, around
    /// its icon and for its name, from four up to six.
    private var columnCount: Int {
        guard !SharedModel.isPhone else {
            return 4
        }
        let panelWidth = min(HomeSearchView.padMaximumWidth, metrics.size.width - 2 * HomeDesign.searchMargin)
        let columnWidth = max(metrics.cellWidth, metrics.iconSize * Self.columnWidthPerIconSize)
        guard columnWidth > 0 else {
            return 4
        }
        return min(max(Int(panelWidth / columnWidth), 4), 6)
    }

    /// How wide a column is for its icon on an iPhone 13 Pro Max: a 396 point
    /// panel in four columns, around 68 point icons.
    private static let columnWidthPerIconSize = 1.45
}
