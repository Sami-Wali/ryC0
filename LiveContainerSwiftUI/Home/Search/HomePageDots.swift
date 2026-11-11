//
//  HomePageDots.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One dot for each page, the one showing in white.
struct HomePageDots: View {
    /// How many pages there are.
    let count: Int
    /// The page showing, counting from 0.
    let current: Int

    var body: some View {
        HStack(spacing: HomeDesign.pageDotSpacing) {
            ForEach(0..<count, id: \.self) { page in
                Circle()
                    .fill(page == current ? Color.white : Color.white.opacity(0.35))
                    .frame(width: HomeDesign.pageDotSize, height: HomeDesign.pageDotSize)
            }
        }
        .animation(HomeDesign.modeChange, value: current)
        .transition(.opacity)
        .accessibilityHidden(true)
    }
}
