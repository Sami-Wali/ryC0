//
//  HomeIconLabel.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An icon's name under it: one line in white, cut short with an ellipsis when
/// it doesn't fit, with a soft shadow over the wallpaper. Like iOS, the Home
/// Screen keeps names at one size whatever the text size setting, so they
/// always fit their column.
struct HomeIconLabel: View {
    /// The name, shown as it is.
    let title: String

    @Environment(WallpaperStore.self) private var wallpaper

    var body: some View {
        Text(verbatim: title)
            .font(.system(size: HomeDesign.labelFontSize, weight: HomeDesign.labelWeight))
            .foregroundStyle(HomeDesign.labelColor)
            .lineLimit(1)
            .truncationMode(.tail)
            // Only once the wallpaper, the halo or a photo, has loaded: on the
            // black shown until then it would cost drawing for nothing.
            .shadow(color: wallpaper.image == nil ? .clear : HomeDesign.labelShadow, radius: HomeDesign.labelShadowRadius, y: 0.5)
    }
}
