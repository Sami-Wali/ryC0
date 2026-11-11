//
//  HomeSettingsIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Settings icon with its name under it.
struct HomeSettingsIcon: View {
    /// Where things go on this screen, for the icon's size.
    let metrics: HomeMetrics
    /// Whether the name shows under the icon. Icons in the dock have none.
    let showsLabel: Bool
    /// Marks the icon as the place Settings zooms out of.
    let zoomSource: HomeZoomSource

    var body: some View {
        VStack(spacing: HomeDesign.labelSpacing) {
            HomeSettingsArtwork(size: metrics.iconSize, cornerRadius: metrics.iconCornerRadius)
                .modifier(HomeIconPointerLift(cornerRadius: metrics.iconCornerRadius))
                .modifier(zoomSource)
            if showsLabel {
                HomeIconLabel(title: "lc.tabView.settings".loc)
            }
        }
    }
}
