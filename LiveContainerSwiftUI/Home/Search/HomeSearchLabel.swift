//
//  HomeSearchLabel.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// "Search" with a magnifying glass, as the search pill shows it.
struct HomeSearchLabel: View {
    var body: some View {
        HStack(spacing: HomeDesign.pillSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: HomeDesign.pillFontSize - 1, weight: .semibold))
            Text("ryc0.home.search".loc)
                .font(.system(size: HomeDesign.pillFontSize, weight: .medium))
        }
        .foregroundStyle(HomeDesign.pillTextColor)
        .transition(.opacity)
    }
}
