//
//  HomeSearchResults.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The apps search found, or suggests before anything is typed, as icons on
/// a glass panel. When nothing matches, it says so.
struct HomeSearchResults: View {
    /// The apps to show.
    let apps: [LCAppModel]
    /// What was searched for, empty before anything is typed.
    let query: String
    /// Where things go on this screen, for the icons' size.
    let metrics: HomeMetrics

    var body: some View {
        if !apps.isEmpty {
            HomeAppGrid(apps: apps, metrics: metrics)
                .padding(.vertical, HomeDesign.searchPanelPadding)
                .homeGlass(.rounded(HomeDesign.searchPanelCornerRadius))
        } else if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        }
    }
}
