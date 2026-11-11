//
//  HomeSearchPill.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The small "Search" pill above the dock, which opens search. While the
/// pages move, and in edit mode, it shows the page dots instead, as on iOS.
struct HomeSearchPill: View {
    /// How many pages there are.
    let pageCount: Int
    /// The page showing, counting from 0.
    let currentPage: Int
    /// Whether the dots show in place of "Search".
    let showsPageDots: Bool
    /// Opens search.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if showsPageDots && pageCount > 1 {
                    HomePageDots(count: pageCount, current: currentPage)
                } else {
                    HomeSearchLabel()
                }
            }
            .frame(height: HomeDesign.pillHeight)
            .padding(.horizontal, HomeDesign.pillPadding)
            .homeGlass(.capsule, isInteractive: true)
            // Lights up under a trackpad or mouse pointer, which can't pull
            // the pages down to open search.
            .contentShape(.hoverEffect, .capsule)
            .hoverEffect(.highlight)
            // A taller touch area than the pill, which is only 30 points high.
            .padding(.vertical, (HomeDesign.minimumTouchSize - HomeDesign.pillHeight) / 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(HomeDesign.modeChange, value: showsPageDots)
        .accessibilityLabel("ryc0.home.search".loc)
        .accessibilityValue("ryc0.home.pageIndicator %lld %lld".localizeWithFormat(currentPage + 1, pageCount))
    }
}
