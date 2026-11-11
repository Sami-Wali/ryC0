//
//  SettingsIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A white symbol on a rounded square of solid color, like the icons beside
/// the rows of the Settings app. It grows with the text size.
struct SettingsIcon: View {
    /// The SF Symbol drawn on the tile.
    let systemImage: String
    /// The tile's color.
    let color: Color

    @ScaledMetric(relativeTo: .body) private var size = SettingsDesign.iconSize

    var body: some View {
        Image(systemName: systemImage)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
            .frame(width: size * SettingsDesign.glyphRatio, height: size * SettingsDesign.glyphRatio)
            .frame(width: size, height: size)
            .background(color, in: .rect(cornerRadius: size * SettingsDesign.iconCornerRatio))
            .accessibilityHidden(true)
    }
}
