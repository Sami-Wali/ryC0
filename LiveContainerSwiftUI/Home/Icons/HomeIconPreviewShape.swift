//
//  HomeIconPreviewShape.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The part of an icon's view that lifts when its long-press menu opens: the
/// icon alone, at the top center, without its name, as on the iOS Home Screen.
struct HomeIconPreviewShape: Shape {
    /// The icon's width and height.
    let iconSize: Double
    /// The icon's corner radius.
    let cornerRadius: Double

    func path(in rect: CGRect) -> Path {
        let icon = CGRect(x: rect.midX - iconSize / 2, y: rect.minY, width: iconSize, height: iconSize)
        return Path(roundedRect: icon, cornerRadius: cornerRadius)
    }
}
